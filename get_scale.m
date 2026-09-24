function get_scale
% Specify coordinates of the points on the calibration target and
% save data to the file.

% ---------------------------- Parameters ---------------------------------
frame_idx = 1;
target_type = 2; % 1) ruler, 2) rectangle
d = [15,39.8]; % (cm) distances between target points: ruler length; rectagle [width, height]

%__________________________________________________________________________
wnd = 7;  thr = 4;
close_im = []; hf = [];
try
% ---------------------------- Open image ---------------------------------
[fn,fp] = uigetfile('*.*', 'Specify a video file / image files', 'MultiSelect','on');
if ~ischar(fp), error('The file is not specified'); end
[read_im, close_im, Nf, im_w, im_h, ext] = open_im(fp,fn);

if frame_idx > Nf
    error('Wrong ''frame_idx'' value');
end
% ---------------------------- Create figure ------------------------------
hf = figure('NumberTitle','off', 'MenuBar','none', 'ToolBar','figure', ...
    'Colormap',gray(256), 'Units','pixels');
tmp1 = get(hf,'Position');
pause('on');
try
    set(hf, 'WindowState','maximized');
catch
    pause(0);
    jFrame = get(handle(hf),'JavaFrame'); %#ok<JAVFM> 
    jFrame.setMaximized(true)
end
tmp = get(hf,'Position');
while ~any(tmp-tmp1)
    pause(0.02)
    tmp = get(hf,'Position');
end
fig_w = tmp(3);    fig_h = tmp(4);

hax = axes('Parent',hf, 'Units','normalized', 'Position',[0,0,1,1], ...
    'DataAspectRatio',[1,1,1], 'PlotBoxAspectRatio',[fig_w,fig_h,fig_h], ...
    'YDir','reverse', 'Visible','off');
try
    addToolbarExplorationButtons(hf)
    set(hax.Toolbar,'Visible','off')
catch
end
% ------------------------------ Read image -------------------------------
im = read_im(frame_idx);
if strcmp(ext,'ptw')
    im = bpr(im, wnd, thr);
end
image('Parent',hax, 'CData',im, 'CDataMapping','scaled');

if strcmp(ext,'ptw')
    set(hf, 'Name','Set the area for the color limits')
    rrect = imrect(hax,[0.5+0.3*im_w, 0.5+0.3*im_h, 0.4*im_w, 0.4*im_h],...
        'PositionConstraintFcn',makeConstrainToRectFcn('imrect', [0.5,im_w+0.5], [0.5,im_h+0.5]));
    wait(rrect);
    roi = im(createMask(rrect));
    set(hax, 'CLim',[min(roi), max(roi)]);
    delete(rrect);
end
% ------------------------------ Specify points ---------------------------
switch target_type
case 1
    set(hf, 'Name','Set position of the ruler marks')
    rline = imline(hax,0.5 + [0.3*im_w,0.5*im_h; 0.7*im_w,0.5*im_h], ...
        'PositionConstraintFcn',makeConstrainToRectFcn('imline', [0.5,im_w+0.5], [0.5,im_h+0.5]));
    wait(rline);
    p_im = getPosition(rline); % image
    p_w = [0,0; d,0]; % world
case 2
    set(hf, 'Name','Set position of the rectangle vertices')
    rpoly = impoly(hax,0.5 + [0.25*im_w,0.25*im_h; 0.25*im_w,0.75*im_h; ...
        0.75*im_w,0.75*im_h; 0.75*im_w,0.25*im_h],...
        'PositionConstraintFcn',makeConstrainToRectFcn('impoly', [0.5,im_w+0.5], [0.5,im_h+0.5]));
    wait(rpoly);
    p_im = getPosition(rpoly);
    p_w = [0,0; 0,d(2); d(1),d(2); d(1),0];
end
% ------------------------------ Save data --------------------------------
save([fp,'scale.mat'], 'fp','fn','frame_idx','target_type','im_w','im_h','p_w','p_im');

error('Done');

catch ME
    close_im; %#ok<VUNUS> 
    if ishghandle(hf), delete(hf); end
    errordlg(ME.message);
end

