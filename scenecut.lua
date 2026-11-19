-- SceneCut for OBS Studio. Copyright 2026 Luciano Di Lauro.
local obs = obslua
local filter_id = "scenecut_portrait_finish_v1"
local engine_id = "background_removal"
local instances = {}
local effect_path = script_path() .. "scenecut.effect"

local function upstream_engine(source)
    local parent = obs.obs_filter_get_parent(source)
    if not parent then return nil end
    local target = obs.obs_filter_get_target(source)
    while target and obs.obs_source_get_type(target) == obs.OBS_SOURCE_TYPE_FILTER do
        if obs.obs_source_get_id(target) == engine_id then return target end
        target = obs.obs_filter_get_target(target)
    end
end

-- Apply changes on the OBS scripting timer, outside the graphics callback.
-- Keep the upstream filter's other settings and avoid restarting inference each tick.
local function sync_engines()
    for data in pairs(instances) do
        local engine = upstream_engine(data.source)
        if engine and obs.obs_source_enabled(data.source) then
            local settings = obs.obs_source_get_settings(engine)
            local current = obs.obs_data_get_double(settings, "temporal_smooth_factor")
            if math.abs(current - data.weight) > 0.0001 then
                obs.obs_data_set_double(settings, "temporal_smooth_factor", data.weight)
                obs.obs_source_update(engine, settings)
            end
            obs.obs_data_release(settings)
        end
    end
end

local filter = {
    id = filter_id,
    type = obs.OBS_SOURCE_TYPE_FILTER,
    output_flags = obs.OBS_SOURCE_VIDEO,
    get_name = function() return "SceneCut" end
}

filter.get_defaults = function(settings)
    obs.obs_data_set_default_int(settings, "edge", 0)
    obs.obs_data_set_default_int(settings, "stability", 30)
    obs.obs_data_set_default_bool(settings, "preview", false)
end

filter.update = function(data, settings)
    data.edge = obs.obs_data_get_int(settings, "edge") / 100
    local stability = obs.obs_data_get_int(settings, "stability") / 100
    -- The engine weights the CURRENT frame. At zero, switch smoothing off.
    data.weight = stability == 0 and 0 or 1 - 0.49 * stability
    data.preview = obs.obs_data_get_bool(settings, "preview")
end

filter.create = function(settings, source)
    obs.obs_enter_graphics()
    local effect = obs.gs_effect_create_from_file(effect_path, nil)
    obs.obs_leave_graphics()
    if not effect then
        obs.script_log(obs.LOG_ERROR, "SceneCut: impossibile caricare scenecut.effect.")
        return nil
    end
    local data = {
        source = source, effect = effect,
        edge_param = obs.gs_effect_get_param_by_name(effect, "edge"),
        preview_param = obs.gs_effect_get_param_by_name(effect, "dark_preview")
    }
    filter.update(data, settings)
    instances[data] = true
    return data
end

filter.destroy = function(data)
    instances[data] = nil
    obs.obs_enter_graphics()
    obs.gs_effect_destroy(data.effect)
    obs.obs_leave_graphics()
end

filter.get_properties = function()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_text(props, "help",
        "Sulla webcam aggiungi prima Background Removal e poi SceneCut. Imposta la sfocatura del motore a zero.", obs.OBS_TEXT_INFO)
    local edge = obs.obs_properties_add_int_slider(props, "edge", "Rifinitura bordi", 0, 90, 1)
    obs.obs_property_set_long_description(edge, "Alza il valore per attenuare i pixel semitrasparenti lungo il contorno.")
    obs.obs_properties_add_int_slider(props, "stability", "Stabilità in movimento", 0, 100, 1)
    obs.obs_properties_add_bool(props, "preview", "Anteprima su fondo scuro")
    return props
end

filter.video_render = function(data)
    if not obs.obs_source_process_filter_begin(data.source, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING) then return end
    obs.gs_effect_set_float(data.edge_param, data.edge)
    obs.gs_effect_set_bool(data.preview_param, data.preview)
    obs.obs_source_process_filter_end(data.source, data.effect, 0, 0)
end

function script_description()
    return "SceneCut 0.1.0 · Prototipo per OBS. Nella webcam aggiungi Background Removal seguito da SceneCut. La modalità scura è visibile anche in registrazione."
end

function script_load()
    obs.obs_register_source(filter)
    obs.timer_add(sync_engines, 500)
end

function script_unload()
    obs.timer_remove(sync_engines)
end
