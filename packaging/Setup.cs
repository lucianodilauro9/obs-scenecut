using System;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Windows.Forms;
using System.Drawing;

internal static class Setup {
    const string Version = "0.2.0";
    static readonly string[] Files = {"scenecut.lua","scenecut.effect","engine/bridge.lua","engine/SceneCutWorker.exe",
        "engine/portrait.onnx","engine/portrait.onnx.license","engine/Apache-2.0.txt","README.md"};
    static bool Equal(string a, string b) {
        using(var hash=SHA256.Create()) using(var x=File.OpenRead(a)) using(var y=File.OpenRead(b)) {
            return Convert.ToBase64String(hash.ComputeHash(x))==Convert.ToBase64String(hash.ComputeHash(y));
        }
    }
    static string Install(string parent) {
        Directory.CreateDirectory(parent);
        string dest=Path.Combine(parent,Version);
        string staging=Path.Combine(parent,".install-"+Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(staging);
        try {
            foreach(string file in Files) {
                string path=Path.Combine(staging,file);
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                using(var data=Assembly.GetExecutingAssembly().GetManifestResourceStream(file))
                using(var output=File.Create(path)) data.CopyTo(output);
            }
            if(Directory.Exists(dest)) {
                foreach(string file in Files)
                    if(!File.Exists(Path.Combine(dest,file)) || !Equal(Path.Combine(dest,file),Path.Combine(staging,file)))
                        throw new IOException("La cartella della versione contiene file differenti. Conservala e scegli un'altra cartella.");
            } else Directory.Move(staging,dest);
            return Path.Combine(dest,"scenecut.lua");
        } finally { if(Directory.Exists(staging)) Directory.Delete(staging,true); }
    }
    [STAThread] static int Main(string[] args) {
        if(args.Length==2 && args[0]=="--extract") {
            try {Install(args[1]);return 0;} catch {return 1;}
        }
        Application.EnableVisualStyles();
        var window=new Form {Text="SceneCut "+Version,ClientSize=new Size(530,210),StartPosition=FormStartPosition.CenterScreen,
            FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false};
        var text=new Label {Left=18,Top=18,Width=494,Height=92,Text="Installa SceneCut per il tuo utente Windows. Il modello per lo scontorno � incluso. Dopo l'installazione potrai caricare il filtro in OBS."};
        var field=new TextBox {Left=18,Top=112,Width=494,ReadOnly=true,Visible=false};
        var button=new Button {Left=18,Top=155,Width=180,Height=32,Text="Installa SceneCut"};
        window.Controls.AddRange(new Control[]{text,field,button});
        button.Click+=delegate {
            try {
                if(field.Visible){Clipboard.SetText(field.Text);return;}
                field.Text=Install(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"SceneCut"));
                field.Visible=true;
                text.Text="1. Copia il percorso qui sotto.\r\n2. In OBS apri Strumenti  Script  + e incollalo nel nome file.\r\n3. Nei Filtri effetto della webcam aggiungi SceneCut.\r\nSe usavi il prototipo, rimuovi prima il vecchio script e il vecchio filtro di rimozione.";
                button.Text="Copia percorso";
            } catch(Exception ex) {MessageBox.Show(window,ex.Message,"SceneCut");}
        };
        Application.Run(window);return 0;
    }
}