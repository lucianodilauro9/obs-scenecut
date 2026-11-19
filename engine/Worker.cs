// SceneCut: local Windows ML inference worker. Frames stay in volatile memory.
using System;
using System.Diagnostics;
using System.IO;
using System.IO.MemoryMappedFiles;
using System.Linq;
using System.Threading;
using Windows.AI.MachineLearning;

internal sealed class PortraitModel : IDisposable {
    public const int Width = 256, Height = 144, Pixels = Width * Height;
    readonly LearningModel model;
    readonly LearningModelSession session;
    readonly LearningModelBinding binding;
    readonly float[] rgb = new float[Pixels * 3];
    readonly float[] history = new float[Pixels];
    bool first = true;
    readonly long[] shape = { 1, Height, Width, 3 };

    public PortraitModel(string path) {
        model = LearningModel.LoadFromFilePath(path);
        session = new LearningModelSession(model, new LearningModelDevice(LearningModelDeviceKind.Cpu));
        binding = new LearningModelBinding(session);
    }
    public void Infer(byte[] rgba, byte[] mask, int stability) {
        for (int i = 0; i < Pixels; ++i) {
            int src = 4 * i, dst = 3 * i;
            rgb[dst] = rgba[src] / 255f;
            rgb[dst+1] = rgba[src+1] / 255f;
            rgb[dst+2] = rgba[src+2] / 255f;
        }
        using (var input = TensorFloat.CreateFromArray(shape, rgb)) {
            binding.Bind("input_1:0", input);
            var evaluation = session.Evaluate(binding, "");
            using (var output = (TensorFloat)evaluation.Outputs["segment:0"]) {
                float[] scores = output.GetAsVectorView().ToArray();
                for (int i = 0; i < Pixels; ++i) {
                    float value = Math.Max(0f, Math.Min(1f, scores[2*i+1]));
                    float difference = Math.Abs(history[i]-value);
                    // Small changes are damped. A large change follows a moving hand immediately.
                    float retain = first ? 0f : 0.78f * stability / 100f * Math.Max(0f, 1f-difference*3f);
                    history[i] = value + (history[i]-value)*retain;
                    mask[i] = (byte)(255f * history[i]+0.5f);
                }
            }
            binding.Clear();
        }
        first = false;
    }
    public void Dispose() { session.Dispose(); model.Dispose(); }
}

internal static class Worker {
    // Header cells: state (0 idle, 1 input, 2 computing, 3 output, 4 error), stop, stability.
    const int Header = 64, InputBytes = 4 * PortraitModel.Pixels;
    static int Main(string[] args) {
        if (args.Length != 2 || !args[0].StartsWith("Local\\SceneCut_")) return 2;
        try {
            using (var parent = Process.GetProcessById(int.Parse(args[1])))
            using (var memory = MemoryMappedFile.OpenExisting(args[0]))
            using (var view = memory.CreateViewAccessor()) {
                try {
                    using (var model = new PortraitModel(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"portrait.onnx"))) {
                        var input = new byte[InputBytes];
                        var mask = new byte[PortraitModel.Pixels];
                        var timer = Stopwatch.StartNew();
                        while (view.ReadInt32(4) == 0) {
                            if (timer.ElapsedMilliseconds > 1000) {
                                if (parent.HasExited) break;
                                timer.Restart();
                            }
                            if (view.ReadInt32(0) != 1) { Thread.Sleep(3); continue; }
                            Thread.MemoryBarrier();
                            view.Write(0,2);
                            view.ReadArray(Header,input,0,input.Length);
                            model.Infer(input,mask,Math.Max(0,Math.Min(100,view.ReadInt32(8))));
                            view.WriteArray(Header + InputBytes,mask,0,mask.Length);
                            Thread.MemoryBarrier();
                            view.Write(0,3);
                        }
                    }
                } catch(Exception ex) {
                    view.Write(12,ex.HResult);
                    Thread.MemoryBarrier();
                    view.Write(0,4);
                    return 1;
                }
            }
            return 0;
        } catch(Exception) { return 2; }
    }
}