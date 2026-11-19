-- Win32 x64 IPC and OBS texture transfer. One inference request per filter.
local ffi = require("ffi")
if not pcall(ffi.typeof, "SC_Startup") then
ffi.cdef[[
typedef struct { uint32_t cb; uint16_t *reserved,*desktop,*title; uint32_t x,y,w,h,cols,rows,fill,flags; uint16_t show,extra; uint8_t *extra_ptr; void *stdin_h,*stdout_h,*stderr_h; } SC_Startup;
typedef struct {void *process,*thread; uint32_t pid,tid;} SC_Process;
void* CreateFileMappingW(void*,void*,uint32_t,uint32_t,uint32_t,const uint16_t*);
void* MapViewOfFile(void*,uint32_t,uint32_t,uint32_t,size_t);
int UnmapViewOfFile(const void*); int CloseHandle(void*);
uint32_t GetCurrentProcessId(void); uint32_t GetTickCount(void);
int MultiByteToWideChar(uint32_t,uint32_t,const char*,int,uint16_t*,int);
int CreateProcessW(const uint16_t*,uint16_t*,void*,void*,int,uint32_t,void*,const uint16_t*,SC_Startup*,SC_Process*);
uint32_t WaitForSingleObject(void*,uint32_t);
void *gs_stagesurface_create(uint32_t,uint32_t,int);
void gs_stagesurface_destroy(void*);
void *gs_get_render_target(void);
void gs_stage_texture(void*,void*);
bool gs_stagesurface_map(void*,uint8_t**,uint32_t*);
void gs_stagesurface_unmap(void*);
void *gs_texture_create(uint32_t,uint32_t,int,uint32_t,const uint8_t**,uint32_t);
void gs_texture_destroy(void*);
void gs_texture_set_image(void*,const uint8_t*,uint32_t,bool);
void *gs_get_effect(void);
void *gs_effect_get_param_by_name(void*,const char*);
void gs_effect_set_texture(void*,void*);
]]
end
local win, gs = ffi.load("kernel32"), ffi.load("obs")
local M = {w=256,h=144}
local pixels = M.w*M.h
local function wide(s)
    local n=win.MultiByteToWideChar(65001,0,s,-1,nil,0)
    local out=ffi.new("uint16_t[?]",n)
    win.MultiByteToWideChar(65001,0,s,-1,out,n)
    return out
end
function M.close(b)
    if b.words then b.words[1]=1 end
    if b.proc then win.CloseHandle(b.proc) end
    if b.view then win.UnmapViewOfFile(b.view) end
    if b.mapping then win.CloseHandle(b.mapping) end
    if b.texture then gs.gs_texture_destroy(b.texture) end
    if b.stage then gs.gs_stagesurface_destroy(b.stage) end
end
function M.open(executable, token)
    local b={}
    local pid=tonumber(win.GetCurrentProcessId())
    local name="Local\\SceneCut_"..pid.."_"..token
    b.mapping=win.CreateFileMappingW(ffi.cast("void*", -1),nil,4,0,64+5*pixels,wide(name))
    if b.mapping==nil then return nil,"Memoria condivisa non disponibile." end
    b.view=win.MapViewOfFile(b.mapping,6,0,0,64+5*pixels)
    if b.view==nil then M.close(b);return nil,"Memoria condivisa non accessibile." end
    b.words=ffi.cast("volatile long*",b.view)
    b.bytes=ffi.cast("uint8_t*",b.view)
    b.stage=gs.gs_stagesurface_create(M.w,M.h,3) -- GS_RGBA
    b.texture=gs.gs_texture_create(M.w,M.h,2,1,nil,2) -- GS_R8, GS_DYNAMIC
    if b.stage==nil or b.texture==nil then M.close(b);return nil,"Texture video non disponibile." end
    local si,pi=ffi.new("SC_Startup[1]"),ffi.new("SC_Process[1]")
    si[0].cb=ffi.sizeof("SC_Startup")
    local cmd=wide('"'..executable..'" "'..name..'" '..pid)
    if win.CreateProcessW(wide(executable),cmd,nil,nil,0,0x08000000,nil,nil,si,pi)==0 then
        M.close(b);return nil,"Impossibile avviare SceneCutWorker.exe. Estrai tutti i file dello ZIP."
    end
    b.proc=pi[0].process
    win.CloseHandle(pi[0].thread)
    b.rows=ffi.new("uint8_t*[1]")
    b.pitch=ffi.new("uint32_t[1]")
    return b
end
function M.state(b)
    if b.words[0]==4 then return -1,("Windows ML: errore %08x"):format(tonumber(b.words[3])) end
    if win.WaitForSingleObject(b.proc,0)==0 then return -1,"Il motore locale si � chiuso." end
    return tonumber(b.words[0])
end
function M.capture(b, stability)
    gs.gs_stage_texture(b.stage,gs.gs_get_render_target())
    if not gs.gs_stagesurface_map(b.stage,b.rows,b.pitch) then return false end
    for y=0,M.h-1 do
        ffi.copy(b.bytes+64+y*M.w*4,b.rows[0]+y*b.pitch[0],M.w*4)
    end
    gs.gs_stagesurface_unmap(b.stage)
    b.words[2]=stability
    b.words[0]=1
    return true
end
function M.receive(b)
    gs.gs_texture_set_image(b.texture,b.bytes+64+4*pixels,M.w,false)
    b.words[0]=0
end
function M.mask_param()
    return gs.gs_effect_get_param_by_name(gs.gs_get_effect(),"portrait_mask")
end
function M.bind(b,param) gs.gs_effect_set_texture(param,b.texture) end
return M
