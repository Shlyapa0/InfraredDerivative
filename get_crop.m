function get_crop
% Specify the position of the crop rectangle and save the data to the file.
% Show position of the crop rectangle from the saved file.

% ---------------------------- Parameters ---------------------------------
show_crop = 0; % if true - visualise data in MAT-file
frame_idx = 1;
flip_im = 0; % if true - make vertical flip
rot90_im = 90; % [0,90,180,270] counterclockwise
rot_im = 1; % if true - enable arbitrary rotation
rot_angle = 0; % (deg) final position of the rotated line

%__________________________________________________________________________
% TODO:
% 3) check variables in memory
% 5) test speed imwarp vs flip+rot90
% 6) frame viewer (choose frames, color limits rect)
% 7) expand rot90
% 8) enable to specify 4 arbitrary points on a plane (not necessary a rectangle)

wnd = 7;  thr = 4;
change_scale = 0;
change_init_rot = 0;
interp_method = 'linear';
close_im = [];  hf = [];
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
% ---------------------------- Show crop data -----------------------------
if show_crop
    [fn1,fp1] = uigetfile([fp,'*.mat'], 'Specify a crop data file');
    if ~ischar(fp1), error('The file is not specified'); end

    msg = lastwarn('');   warning('off','MATLAB:load:variableNotFound')
    load([fp1,fn1], 'flip_im','rot90_im','is_tform','tform','r1');
    msg = lastwarn(msg);   warning('on','MATLAB:load:variableNotFound')
    if ~isempty(msg)
        error('Wrong crop data file');
    end

    if is_tform
        [im,ref2] = imwarp(im, tform, interp_method);
        xl = ref2.XWorldLimits;    yl = ref2.YWorldLimits;
    else
        if flip_im
            im = flip(im);
        end
        switch rot90_im
        case 90
            im = rot90(im, 1);
        case 180
            im = rot90(im, 2);
        case 270
            im = rot90(im, 3);
        end
        xl = [0.5,im_w+0.5]; yl = [0.5,im_h+0.5];
    end

    set(hf, 'Name','Check crop')
    image('Parent',hax, 'XData',[xl(1)+0.5,xl(2)-0.5],'YData',[yl(1)+0.5,yl(2)-0.5],...
        'CData',im, 'CDataMapping','scaled');

    rrect = imrect(hax, [r1(1), r1(3), diff(r1)],...
        'PositionConstraintFcn',makeConstrainToRectFcn('imrect',xl,yl));
    if strcmp(ext,'ptw')
        roi = im(createMask(rrect));
        set(hax, 'CLim',[min(roi), max(roi)]);
    end
    wait(rrect);
    error('Done');
end
% ------------------------------ Show image -------------------------------
him = image('Parent',hax, 'CData',im, 'CDataMapping','scaled');

if strcmp(ext,'ptw')
    set(hf, 'Name','Set the area for the color limits')
    rrect = imrect(hax,[0.5+0.3*im_w, 0.5+0.3*im_h, 0.4*im_w, 0.4*im_h],...
        'PositionConstraintFcn',makeConstrainToRectFcn('imrect', [0.5,im_w+0.5], [0.5,im_h+0.5]));
    wait(rrect);
    roi = im(createMask(rrect));
    set(hax, 'CLim',[min(roi), max(roi)]);
    delete(rrect);
end
% ---------------------------- Load scale data ----------------------------
[fn1,fp1] = uigetfile([fp,'*.mat'], 'Specify a scale data file');
if ~ischar(fp1), error('The file is not specified'); end

im1_w = im_w; im1_h = im_h;
msg = lastwarn('');   warning('off','MATLAB:load:variableNotFound')
load([fp1,fn1], 'target_type','im_w','im_h','p_w','p_im');
msg = lastwarn(msg);   warning('on','MATLAB:load:variableNotFound')
if ~isempty(msg) || im_w ~= im1_w || im_h ~= im1_h
    error('Wrong scale data file');
end
scale_file_path = [fp1,fn1];
% ---------------------------- Determine scale ----------------------------
switch target_type
case 1
    scale = sqrt( sum(diff(p_im).^2) / sum(diff(p_w).^2) ); % pix/cm
case 2
    p_sc = 0.5 + [0,0.5*im_h; im_w,0.5*im_h];
    if change_scale
        set(hf, 'Name','Set the position and direction to get scale')
        rline = imline(hax, p_sc, ...
            'PositionConstraintFcn',makeConstrainToRectFcn('imline',[0.5,im_w+0.5], [0.5,im_h+0.5]));
        wait(rline);
        p_sc = getPosition(rline);
        delete(rline);
    end
    
    p_ir = 0.5 + [0.5*im_w,0; 0.5*im_w,im_h];
    if change_init_rot
        set(hf, 'Name','Set the initial orientation')
        rline = imline(hax, p_ir, ...
        'PositionConstraintFcn',makeConstrainToRectFcn('imline',[0.5,im_w+0.5], [0.5,im_h+0.5]));
        wait(rline);
        p_ir = getPosition(rline);
        delete(rline);
    end
    
    tform = fitgeotrans(p_im, p_w, 'projective');
    
    p1_sc = transformPointsForward(tform, p_sc);
    scale = sqrt( sum(diff(p_sc).^2) / sum(diff(p1_sc).^2) ); % pix/cm
    
    p1_ir = transformPointsForward(tform, p_ir);
    c = scale * sqrt( sum(diff(p1_ir).^2) / sum(diff(p_ir).^2) );
    tform = fitgeotrans(p1_ir, c*p_ir, 'nonreflectivesimilarity');
    p_w = transformPointsForward(tform, p_w);
end
% ---------------------------- Flip and rot90 -----------------------------
T = eye(3);
if flip_im
    T = T*[1,0,0; 0,-1,0; 0,0,1];
end
switch rot90_im
case 90
    T = T*[0,-1,0; 1,0,0; 0,0,1];
case 180
    T = T*[-1,0,0; 0,-1,0; 0,0,1];
case 270
    T = T*[0,1,0; -1,0,0; 0,0,1]; 
end

tform = affine2d(T);
if target_type > 1
    tform = fitgeotrans(p_im, transformPointsForward(tform,p_w), 'projective');
end

[im1,ref] = imwarp(im, tform, interp_method);
xl = ref.XWorldLimits;    yl = ref.YWorldLimits;
dx = xl(2)-xl(1);         dy = yl(2)-yl(1);

set(him, 'XData',[xl(1)+0.5, xl(2)-0.5], 'YData',[yl(1)+0.5, yl(2)-0.5], 'CData',im1)

% --------------------------- Rotate arbitrary ----------------------------
if rot_im
    set(hf, 'Name','Set the rotation line')
    rline = imline(hax,[xl(1)+0.3*dx,yl(1)+0.5*dy; xl(1)+0.7*dx,yl(1)+0.5*dy], ...
        'PositionConstraintFcn',makeConstrainToRectFcn('imline',xl,yl));
    wait(rline);
    p_r = getPosition(rline);
    delete(rline);
    
    d = diff(p_r);
    a = -pi/180*rot_angle - atan2(d(2),d(1));
    T = T*[cos(a),sin(a),0; -sin(a),cos(a),0; 0,0,1];
    
    tform = affine2d(T);
    if target_type > 1
        tform = fitgeotrans(p_im, transformPointsForward(tform,p_w), 'projective');
    end

    [im1,ref] = imwarp(im, tform, interp_method);
    xl = ref.XWorldLimits;    yl = ref.YWorldLimits;
    dx = xl(2)-xl(1);         dy = yl(2)-yl(1);

    set(him, 'XData',[xl(1)+0.5,xl(2)-0.5], 'YData',[yl(1)+0.5,yl(2)-0.5], 'CData',im1)
end
% ----------------------- Specify crop rectangle --------------------------
set(hf, 'Name','Set the area for the color limits')
rrect = imrect(hax,[xl(1)+0.3*dx, yl(1)+0.3*dy, 0.4*dx, 0.4*dy],...
    'PositionConstraintFcn',makeConstrainToRectFcn('imrect',xl,yl));
wait(rrect);
roi = im1(createMask(rrect));
set(hax, 'CLim',[min(roi), max(roi)]);

set(hf, 'Name','Set the crop rectangle')
wait(rrect);
p_r = getPosition(rrect);

% round position to whole pixels
x1 = xl(1) + round(p_r(1)-xl(1));
x2 = xl(1) + round(p_r(1)+p_r(3)-xl(1));
y1 = yl(1) + round(p_r(2)-yl(1));
y2 = yl(1) + round(p_r(2)+p_r(4)-yl(1));
r1 = [x1,y1; x2,y2];
ref1 = imref2d([y2-y1,x2-x1], [x1,x2], [y1,y2]);

% get the rectangle roi in the original image
xy1 = [x1,y1; x1,y2; x2,y2; x2,y1];
xy = transformPointsInverse(tform, xy1);
x1 = max(floor(min(xy(:,1))), 1);
x2 = min( ceil(max(xy(:,1))), im_w);
y1 = max(floor(min(xy(:,2))), 1);
y2 = min( ceil(max(xy(:,2))), im_h);
r = [x1,y1; x2,y2];
ref = imref2d([y2-y1+1,x2-x1+1], [x1-0.5,x2+0.5], [y1-0.5,y2+0.5]);

is_tform = target_type > 1 || rot_im;

% ------------------------------ Save data --------------------------------
save([fp,'crop.mat'], ...
    'fp','fn','frame_idx','flip_im','rot90_im','rot_im','rot_angle','scale_file_path',...
    'is_tform','im_w','im_h','scale','tform','r','ref','r1','ref1');

error('Done');

catch ME
    close_im; %#ok<VUNUS> 
    if ishghandle(hf), delete(hf); end
    errordlg(ME.message);
end

