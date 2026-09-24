function IR_spectrum
% Calculate dT/dx, dT/dy, sqrt((dT/dx)^2 + (dT/dy)^2)

% --------------------------- Parameters ----------------------------------
frame_idx = 1;
wnd = 7;  thr = 4;
interp_method = 'linear'; % imwarp: nearest, linear, cubic

%__________________________________________________________________________
% TODO:
% 1) progress bar mod Inf

close_im = [];  pb_f = []; hf = [];
fft_wisdom = fftw('wisdom');    fftw('wisdom','');
fft_method = fftw('planner');   fftw('planner','patient');
try
% ---------------------------- Open image ---------------------------------
[fn,fp] = uigetfile('*.*', 'Specify *.ptw file');
if ~ischar(fp), error('The file is not specified'); end

[read_im, close_im, Nf1, im_w, im_h, ext] = open_im(fp,fn);

if max(frame_idx) > Nf1
    error('Wrong ''frame_idx'' value');
end
% ---------------------------- Load crop data -----------------------------
im1_w = im_w; im1_h = im_h;
msg = lastwarn('');   warning('off','MATLAB:load:variableNotFound')
load([fp,'crop.mat'], 'flip_im','rot90_im',...
    'is_tform','im_w','im_h','scale','tform','r','ref','ref1');
msg = lastwarn(msg);   warning('on','MATLAB:load:variableNotFound')
if ~isempty(msg) || im_w ~= im1_w || im_h ~= im1_h
    error('Wrong crop data file');
end
% ------------------------------ Main loop --------------------------------
Nf = numel(frame_idx);
sz = ref1.ImageSize;
w = sz(2);               h = sz(1);
Nkx = floor(w/2+1);      Nky = floor(h/2+1);
dkx = 2*pi*scale/w;      dky = 2*pi*scale/h; % cm^{-1}
kx = dkx*[Nkx-w,Nkx-1];  ky = dky*[Nky-h,Nky-1];
sp = zeros(h,w);

pb_f = figure('Name','0.0 %','Units','normalized','Position',[0.4,0.5,0.2,eps],...
    'Toolbar','none','MenuBar','none','NumberTitle','off','WindowStyle','modal');
figure(pb_f);
pb_t = tic;

for ind = 1 : Nf
    im = read_im(frame_idx(ind));
    im = im(r(3):r(4), r(1):r(2));
    if strcmp(ext,'ptw')
        im = bpr(im, wnd, thr);
    end

    if is_tform
        im = imwarp(im, ref, tform, interp_method, 'OutputView',ref1);
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
    end
    
    sp = sp + abs(fft2(single(im)));
    
    a = ind/Nf;
    set(pb_f,'Name',sprintf('%.2f %%, %d:%02d:%02d:%02d left', 100*a, ...
        mod(floor((1/a-1)*toc(pb_t)./[8.64e4,3600,60,1]), [Inf,24,60,60])))
    figure(pb_f);
end

sp = circshift(sp,[h-Nky,w-Nkx]) ./ (Nf*w*h);

% ------------------------------ Save data --------------------------------
save([fp,'spectrum_xy.mat'], ...
    'fp','fn','frame_idx','wnd','thr','interp_method','sp','dkx','dky');

sp(1+h-Nky,1+w-Nkx) = 0; % remove zero frequency

file_fmt = '-dpng';
print_res = '-r300';
font_name = 'Times New Roman';
font_size = 12;
fw = 12; % cm
mg = [1.8,2,1.8,0.5]; % margins - left, right, bottom, top (cm)

aw = fw - mg(1) - mg(2);
ah = aw;
fh = ah + mg(3) + mg(4);
    
hf = figure('Visible','off', 'Colormap',jet(256), 'Units','centimeters',...
    'Position',[0,0,fw,fh], 'PaperPositionMode','auto');
hax = axes('DataAspectRatio',[1,1,1], 'PlotBoxAspectRatio',[aw,ah,ah], ...
    'TickDir','out', 'Box','on', 'Layer','top', ...
    'FontName',font_name, 'FontSize',font_size);
image('XData',kx,'YData',ky,'CData',log10(sp),'CDataMapping','scaled');
hcb = colorbar('EastOutside');
set(hcb, 'TickDir','out', 'Units','centimeters', ...
    'Position',[mg(1)+aw+0.1*mg(2), mg(3), 0.2*mg(2), ah])
set(hax, 'Units','centimeters', 'Position',[mg(1),mg(3),aw,ah])
xlabel('\itk_x\rm, cm^{-1}');
ylabel('\itk_y\rm, cm^{-1}');

print(hf,[fp,'spectrum_xy'], file_fmt, print_res);

error('Done');

catch ME
    fftw('wisdom',fft_wisdom);
    fftw('planner',fft_method);
    close_im; %#ok<VUNUS>
    if ishghandle(pb_f), delete(pb_f); end
    if ishghandle(hf), delete(hf); end
    errordlg(ME.message);
end
