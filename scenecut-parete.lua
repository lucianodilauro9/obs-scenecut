-- SceneCut: background subtraction for a fixed webcam, using OBS graphics only.
local obs = obslua
local capture_delay = 3000000000
local shader = [[
uniform float4x4 ViewProj;
uniform texture2d image;
uniform texture2d reference;
uniform float tolerance;
sampler_state sample_linear { Filter = Linear; AddressU = Clamp; AddressV = Clamp; };
struct Vertex { float4 pos : POSITION; float2 uv : TEXCOORD0; };
Vertex vertex_main(Vertex v) { v.pos = mul(float4(v.pos.xyz,1.0),ViewProj); return v; }
float4 remove_wall(Vertex v) : TARGET
{
    float4 camera = image.Sample(sample_linear,v.uv);
    float3 wall = reference.Sample(sample_linear,v.uv).rgb;
    float3 delta = abs(camera.rgb-wall);
    float distance = max(delta.r,max(delta.g,delta.b));
    float opacity = smoothstep(tolerance,tolerance+0.07,distance);
    return camera*opacity;
}
technique Draw { pass { vertex_shader = vertex_main(v); pixel_shader = remove_wall(v); } }
]]

local filter = {
    id = "scenecut_static_wall_v1",
    type = obs.OBS_SOURCE_TYPE_FILTER,
    output_flags = obs.OBS_SOURCE_VIDEO
}
filter.get_name = function() return "SceneCut - Parete fissa" end
filter.get_defaults = function(settings)
    obs.obs_data_set_default_int(settings, "tolerance", 10)
end
filter.update = function(data, settings)
    data.tolerance = obs.obs_data_get_int(settings, "tolerance") / 100
end
filter.create = function(settings, source)
    local data = {source=source, ready=false}
    obs.obs_enter_graphics()
    data.effect = obs.gs_effect_create(shader, "scenecut-parete.effect", nil)
    if data.effect then
        data.reference_param = obs.gs_effect_get_param_by_name(data.effect, "reference")
        data.tolerance_param = obs.gs_effect_get_param_by_name(data.effect, "tolerance")
        data.reference = obs.gs_texrender_create(obs.GS_RGBA, obs.GS_ZS_NONE)
    end
    obs.obs_leave_graphics()
    filter.update(data, settings)
    return data
end
filter.destroy = function(data)
    obs.obs_enter_graphics()
    if data.reference then obs.gs_texrender_destroy(data.reference) end
    if data.effect then obs.gs_effect_destroy(data.effect) end
    obs.obs_leave_graphics()
end
filter.get_properties = function(data)
    local properties = obs.obs_properties_create()
    obs.obs_properties_add_text(properties, "instructions",
        "Webcam ferma. Premi il pulsante ed esci per 3 secondi. Rientra quando la parete scompare. Ripeti la cattura se sposti la camera o riapri OBS.",
        obs.OBS_TEXT_INFO)
    if data then
        if not data.reference then
            obs.obs_properties_add_text(properties, "error", "Filtro grafico non disponibile. La webcam resta visibile.", obs.OBS_TEXT_INFO)
        end
        obs.obs_properties_add_button(properties, "capture", "Memorizza parete tra 3 secondi", function()
            data.deadline = obs.os_gettime_ns() + capture_delay
            data.ready = false
            return false
        end)
    end
    obs.obs_properties_add_int_slider(properties, "tolerance", "Tolleranza alle variazioni della parete", 1, 40, 1)
    return properties
end
local function capture_reference(data, width, height)
    obs.gs_texrender_reset(data.reference)
    if not obs.gs_texrender_begin(data.reference, width, height) then return false end
    obs.gs_ortho(0,width,0,height,-100,100)
    local clear = obs.vec4()
    obs.gs_clear(obs.GS_CLEAR_COLOR,clear,0,0)
    obs.gs_blend_state_push()
    obs.gs_blend_function(obs.GS_BLEND_ONE,obs.GS_BLEND_ZERO)
    obs.obs_source_skip_video_filter(data.source)
    obs.gs_blend_state_pop()
    obs.gs_texrender_end(data.reference)
    data.width, data.height = width, height
    return true
end
filter.video_render = function(data)
    local target = obs.obs_filter_get_target(data.source)
    if not target then return end
    local width, height = obs.obs_source_get_base_width(target), obs.obs_source_get_base_height(target)
    if data.ready and (width ~= data.width or height ~= data.height) then data.ready = false end
    if data.reference and data.deadline and obs.os_gettime_ns() >= data.deadline and width > 0 and height > 0 then
        data.ready = capture_reference(data, width, height)
        if data.ready then data.deadline = nil end
    end
    if not data.ready then
        obs.obs_source_skip_video_filter(data.source)
        return
    end
    if obs.obs_source_process_filter_begin(data.source, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING) then
        obs.gs_effect_set_texture(data.reference_param, obs.gs_texrender_get_texture(data.reference))
        obs.gs_effect_set_float(data.tolerance_param, data.tolerance)
        obs.obs_source_process_filter_end(data.source, data.effect, width, height)
    end
end
function script_description() return "SceneCut - Parete fissa. Aggiungi il filtro alla webcam, lascia vuota l'inquadratura per la cattura e rientra. Il riferimento rimane in memoria per questa sessione." end
function script_load() obs.obs_register_source(filter) end
