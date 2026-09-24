function frame_viewer
% 1) Select image/video files
% 2) Click on the 'rectangle' tool and specify the region of interest (ROI)
% 3) Click on the 'submit' tool and save the roi file

%%%%%%%%%%%  make V nonscalar structure array (multiple program windows)
%%%%%%%%%%%  load roi data

data_file = 'frame_viewer_data.mat';
%__________________________________________________________________________
global V

if ~isempty(V)
    errordlg('The program window / global variable V already exists'); return
end

try
    s = load(data_file,'start_path');
catch
    s.start_path = '';
    s.rpos = zeros(1,6);
    save(data_file,'-struct','s');
end

[fn,fp] = uigetfile([s.start_path,'*.*'],'Select images/video files', 'MultiSelect','on');
if ~ischar(fp)
    clear global V
    return
elseif ~iscell(fn)
    fn = {fn};
end
s.start_path = fp;
save(data_file,'-struct','s','-append');
V.data_file = data_file;

fn1 = fn{1};
k = strfind(fn1,'.');
if isempty(k)
    ext = '';
else
    ext = fn1(k(end)+1 : end); % file extension
end

V.fid = -1;
V.is_CLim = false;

if strcmp(ext,'ptw')
    fid = fopen([fp,fn1]);
    if fid == -1
        errordlg('*.ptw file can''t be opened'); clear global V; return
    end
    fseek(fid, 11, 'bof');
    V.mh_sz = fread(fid,1,'int32'); % in bytes
    V.fh_sz = fread(fid,1,'int32'); % in bytes
    fseek(fid, 27, 'bof');
    Nf = fread(fid,1,'int32');
%     fseek(fid, 141, 'bof');
%     V.emissivity = fread(fid,1,'float');
%     V.T_bgr = fread(fid,1,'float'); % in K
    fseek(fid, 377, 'bof');
    V.n_cols = fread(fid,1,'uint16');
    V.n_rows = fread(fid,1,'uint16');
    V.f_sz = V.fh_sz + 2*V.n_rows*V.n_cols;
    V.fid = fid;
    frame = read_ptw(1);
    V.read_f = @read_ptw;
    V.is_CLim = true;
    V.mask = true(size(frame));
else
    try
        video = VideoReader([fp,fn1]);
        frame = read(video,1);
        Nf = get(video,'NumberOfFrames');
        V.read_f = @(ind) read(video,ind);
    catch
        try
            frame = imread([fp,fn1]);
            Nf = numel(fn);
            V.read_f =  @(ind) imread([fp,fn{ind}]);
        catch
            errordlg('Wrong data type'); clear global V; return
        end
    end
end

V.f = figure('NumberTitle','off', 'Name',[fp,fn1], 'ToolBar','figure', 'Visible','off', 'Colormap',gray(256));
V.ax = axes('Units','pixels');
V.im = image('CData',frame,'CDataMapping','scaled');
axis ij image off
clear frame

set(groot,'Units','pixels')
pos = get(groot,'ScreenSize');
V.t_sz(2) = 0.03*min(pos(3:4)); % text field size in pixels
V.t_sz(1) = 0.5*V.t_sz(2) * numel(sprintf('%d/%d',Nf,Nf));
V.t = uicontrol('Style','text', 'FontUnits','pixels', 'FontSize',0.8*V.t_sz(2), 'String',sprintf('1/%d',Nf));

if Nf > 1
    V.sl = uicontrol('Style','slider', 'BackgroundColor',[1,1,1]*0.5, ...
        'Min',1, 'Max',Nf, 'Value',1, 'SliderStep',[1/(Nf-1), 10/(Nf-1)]);
    addlistener(V.sl,'Value','PostSet',@slider);
else
    V.sl = uicontrol('Style','slider','Enable','off');
end

try
    addToolbarExplorationButtons(V.f)
    set(V.ax.Toolbar,'Visible','off')
catch
end

htb = findall(V.f,'Type','uitoolbar');
htls = allchild(htb);
set(htls, 'Visible','off', 'Separator','off');
set(findobj(htls,'Tag','Exploration.Pan','-or','Tag','Exploration.ZoomOut','-or','Tag','Exploration.ZoomIn'), 'Visible','on');
icons = load('icons.mat');
uitoggletool(htb,'CData',icons.rect, 'TooltipString','Rectangle', 'OnCallback',@rect_on, 'OffCallback',@rect_off);
V.rect_ok = uipushtool(htb,'CData',icons.ok, 'TooltipString','Submit', 'ClickedCallback',@rect_ok, 'Visible','off');
uitoggletool(htb,'CData',icons.ruler, 'TooltipString','Ruler', 'OnCallback',@ruler_on, 'OffCallback',@ruler_off);

V.Nf = Nf;

set(V.f,'ResizeFcn',@res_fcn, 'KeyPressFcn',@key_fcn, 'CloseRequestFcn',@close_fcn, 'Visible','on')
try
    set(V.f, 'WindowState','maximized')
catch
    WindowAPI(V.f,'Maximize')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function frame = read_ptw(ind)
global V
% remove bad pixels in *.ptw (median filter)
wnd = 7; % window size
thr = 4; % outlier threshold (in std)

fseek(V.fid, V.mh_sz + (ind-1)*V.f_sz + V.fh_sz,'bof');
frame = fread(V.fid,[V.n_cols,V.n_rows],'*uint16').';

% median filter
M = ordfilt2(frame,ceil(0.5*wnd*wnd),ones(wnd,wnd),'symmetric');
tmp = frame - M;
ind = frame < M; % uint
tmp(ind) = M(ind) - frame(ind);
ind = tmp > thr * 1.4826*ordfilt2(tmp,ceil(0.5*wnd*wnd),ones(wnd,wnd),'symmetric');
frame(ind) = M(ind);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res_fcn(~,~)
global V
pos = get(V.f,'Position');
set(V.ax,'Position',[0,V.t_sz(2),pos(3),pos(4)-V.t_sz(2)]);
set(V.sl,'Position',[0,0,pos(3)-V.t_sz(1),V.t_sz(2)]);
set(V.t,'Position',[pos(3)-V.t_sz(1),0,V.t_sz]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function slider(~,~)
global V
ind = round(get(V.sl,'Value'));
set(V.t,'String',sprintf('%d/%d',ind,V.Nf));
try
    frame = V.read_f(ind);
    set(V.im,'CData',frame);
    if V.is_CLim
        roi = frame(V.mask);
        set(V.ax,'CLim',[min(roi),max(roi)]);
    end
catch
    set(V.im,'CData',reshape([0,0,0],1,1,3))
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function key_fcn(~,event)
global V

switch event.Key
    case 'leftarrow'
        set(V.sl, 'Value',max(get(V.sl,'Min'), get(V.sl,'Value')-1))
    case 'rightarrow'
        set(V.sl, 'Value',min(get(V.sl,'Max'), get(V.sl,'Value')+1))
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function rect_on(~,~)
global V
s = load(V.data_file,'rpos');
[h,w,~] = size(get(V.im,'CData'));
if s.rpos(1) == w && s.rpos(2) == h
    V.rect = imrect(V.ax,s.rpos(3:6));
else
    xlim = get(V.ax,'XLim');
    ylim = get(V.ax,'YLim');
    dx = xlim(2) - xlim(1);
    dy = ylim(2) - ylim(1);
    V.rect = imrect(V.ax,[xlim(1)+0.3*dx,ylim(1)+0.3*dy,0.4*dx,0.4*dy]);
end
setPositionConstraintFcn(V.rect, makeConstrainToRectFcn('imrect', [0.5,w+0.5], [0.5,h+0.5]));
set(V.rect_ok,'Visible','on');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function rect_off(~,~)
global V
delete(V.rect);
set(V.rect_ok,'Visible','off');
if V.is_CLim
    V.mask(:) = true;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function rect_ok(~,~)
global V
if V.is_CLim
    V.mask = createMask(V.rect);
    frame = get(V.im,'CData');
    roi = frame(V.mask);
    set(V.ax,'CLim',[min(roi),max(roi)]);
end

s = load(V.data_file,'start_path');
[fn,fp] = uiputfile('*.mat','Save roi file',[s.start_path,'roi.mat']);
if ~ischar(fp)
    return
end

[h,w,~] = size(get(V.im,'CData'));
rpos = [w, h, getPosition(V.rect)];
% [m1,m2,n1,n2] = round([rpos(4)+0.5, rpos(4)+rpos(6)-0.5, rpos(3)+0.5, rpos(3)+rpos(5)-0.5]);
save(V.data_file,'rpos','-append');
save([fp,fn],'rpos');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ruler_on(~,~)
global V
V.dist_line = imdistline(V.ax);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ruler_off(~,~)
global V
delete(V.dist_line);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function close_fcn(~,~)
global V
delete(V.f)
if V.fid ~= -1
    fclose(V.fid);
end
clear global V

% V: read_f, f, ax, im, t_sz, t, sl, rect_ok, Nf, data_file, rect, dist_line
% mh_sz, fh_sz, f_sz, fid, n_cols, n_rows
% is_CLim, mask