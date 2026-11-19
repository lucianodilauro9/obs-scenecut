-- SceneCut 0.2.0, Windows x64. Keep the original filter ID for existing scenes.
local o=obslua
local root=script_path()
local bridge=dofile(root.."engine/bridge.lua")
local filter={id="scenecut_portrait_finish_v1",type=o.OBS_SOURCE_TYPE_FILTER,output_flags=o.OBS_SOURCE_VIDEO}
filter.get_name=function() return "SceneCut" end
filter.get_defaults=function(s)
    o.obs_data_set_default_int(s,"edge",12)
    o.obs_data_set_default_int(s,"stability",35)
    o.obs_data_set_default_bool(s,"preview",false)
end
filter.update=function(d,s)
    d.edge=o.obs_data_get_int(s,"edge")/100
    d.stability=o.obs_data_get_int(s,"stability")
    d.preview=o.obs_data_get_bool(s,"preview")
end
local function target() return o.gs_texrender_create(o.GS_RGBA,o.GS_ZS_NONE) end
filter.create=function(settings,source)
    local d={source=source, tick=true, width=0,height=0,valid=false}
    o.obs_enter_graphics()
    d.effect=o.gs_effect_create_from_file(root.."scenecut.effect",nil)
    if d.effect then
        d.image=o.gs_effect_get_param_by_name(d.effect,"image")
        d.refine=o.gs_effect_get_param_by_name(d.effect,"edge")
        d.dark=o.gs_effect_get_param_by_name(d.effect,"dark_preview")
        while o.gs_effect_loop(d.effect,"Draw") do d.mask=bridge.mask_param() end
        d.front,d.pending,d.small=target(),target(),target()
    end
    o.obs_leave_graphics()
    if not d.effect then o.script_log(o.LOG_ERROR,"SceneCut: shader mancante o incompatibile.");return nil end
    filter.update(d,settings)
    return d
end
local function stop_engine(d)
    if d.engine then bridge.close(d.engine);d.engine=nil end
    d.valid=false
end
filter.destroy=function(d)
    o.obs_enter_graphics()
    stop_engine(d)
    o.gs_texrender_destroy(d.front);o.gs_texrender_destroy(d.pending);o.gs_texrender_destroy(d.small)
    o.gs_effect_destroy(d.effect)
    o.obs_leave_graphics()
end
filter.get_properties=function(d)
    local p=o.obs_properties_create()
    o.obs_properties_add_text(p,"info",d and d.error or "Scontorno IA locale. Posiziona la webcam sopra lo sfondo nella scena.",o.OBS_TEXT_INFO)
    o.obs_properties_add_int_slider(p,"edge","Rifinitura bordi",0,90,1)
    o.obs_properties_add_int_slider(p,"stability","Stabilit� in movimento",0,100,1)
    o.obs_properties_add_bool(p,"preview","Anteprima su fondo scuro")
    return p
end
filter.video_tick=function(d) d.tick=true end
filter.activate=function(d) d.restart=true end
local function start_target(t,w,h)
    o.gs_texrender_reset(t)
    if not o.gs_texrender_begin(t,w,h) then return false end
    o.gs_ortho(0,w,0,h,-100,100)
    return true
end
local function submit(d,w,h)
    if not start_target(d.pending,w,h) then return end
    local base=o.obs_get_base_effect(o.OBS_EFFECT_DEFAULT)
    local got=o.obs_source_process_filter_begin(d.source,o.GS_RGBA,o.OBS_NO_DIRECT_RENDERING)
    if got then o.obs_source_process_filter_end(d.source,base,w,h) end
    o.gs_texrender_end(d.pending)
    if not got or not start_target(d.small,bridge.w,bridge.h) then return end
    local tex=o.gs_texrender_get_texture(d.pending)
    o.gs_effect_set_texture(o.gs_effect_get_param_by_name(base,"image"),tex)
    while o.gs_effect_loop(base,"Draw") do o.gs_draw_sprite(tex,0,bridge.w,bridge.h) end
    bridge.capture(d.engine,d.stability)
    o.gs_texrender_end(d.small)
end
local function failure(d,reason)
    stop_engine(d)
    d.error=reason
    o.script_log(o.LOG_ERROR,"SceneCut: "..reason)
    o.obs_source_update_properties(d.source)
end
filter.video_render=function(d)
    local src=o.obs_filter_get_target(d.source)
    if not src or (d.error and not d.restart) then return end
    local w,h=o.obs_source_get_base_width(src),o.obs_source_get_base_height(src)
    if w==0 or h==0 then return end
    if d.restart or w~=d.width or h~=d.height then
        d.restart=false; d.error=nil
        stop_engine(d);d.width=w;d.height=h
    end
    if not d.engine then
        local err
        d.engine,err=bridge.open(root.."engine/SceneCutWorker.exe",o.obs_source_get_uuid(d.source).."_"..tostring(o.os_gettime_ns()))
        if not d.engine then failure(d,err);return end
    end
    if d.tick then
        d.tick=false
        local state,err=bridge.state(d.engine)
        if state==-1 then failure(d,err);return end
        if state==3 then
            bridge.receive(d.engine)
            d.front,d.pending=d.pending,d.front
            d.valid=true
            state=0
        end
        if state==0 then
            o.gs_blend_state_push()
            o.gs_blend_function(o.GS_BLEND_ONE,o.GS_BLEND_ZERO)
            submit(d,w,h)
            o.gs_blend_state_pop()
        end
    end
    if not d.valid then return end
    local tex=o.gs_texrender_get_texture(d.front)
    o.gs_effect_set_texture(d.image,tex)
    bridge.bind(d.engine,d.mask)
    o.gs_effect_set_float(d.refine,d.edge)
    o.gs_effect_set_bool(d.dark,d.preview)
    while o.gs_effect_loop(d.effect,"Draw") do o.gs_draw_sprite(tex,0,w,h) end
end
function script_description() return "SceneCut 0.2.0 � Filtro webcam autonomo per Windows x64. Aggiungi SceneCut nei filtri effetto. Il fondo scuro si vede anche in registrazione." end
function script_load() o.obs_register_source(filter) end
