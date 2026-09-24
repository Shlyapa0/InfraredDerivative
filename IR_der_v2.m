function Txy_mean = IR_der_v2(options)
    arguments
        options.Scale (1,1) double = 12.3/392; % cm/pix
        options.FrameIndex (1,1) int64 = 1;
        options.FileName (1,1) string = "";
        options.FilePath (1,1) string = "";
    end

% Calculate dT/dx, dT/dy, sqrt((dT/dx)^2 + (dT/dy)^2)

scale = options.Scale; % cm/pix
frame_idx = options.FrameIndex;
wnd = 7;
thr = 4;
sigma = 3;

fpc = 'E:\IR\Calib\';
fnc = '05_80_1053mks_25mm.exp';

%__________________________________________________________________________

close_im = []; 
% try
% ---------------------------- Set file -----------------------------------
if strlength(string(options.FileName)) > 0 
    fn = char(options.FileName);
    fp = char(options.FilePath);
else
   [fn,fp] = uigetfile('*.ptw', 'Specify *.ptw file');
   if isequal(fn, 0) error('Файл не выбран.'); end
end

[read_im, close_im, Nf1, im_w, im_h, ext, f_T_obj] = open_im(fp,fn, fpc,fnc);

if max(frame_idx) > Nf1
    error('Wrong ''frame_idx'' value');
end

k = strfind(fn,'.ptw');
fp1 = [fp,fn(1:k-1),'\'];
[~,~] = mkdir(fp1);

% ---------------------------- Set roi ------------------------------------

hf = figure('NumberTitle','off', 'Name',[fp,fn], 'ToolBar','figure', 'Colormap',gray(256));
try
    set(hf, 'WindowState','maximized');
catch
    pause(0);
    jFrame = get(handle(hf),'JavaFrame');
    jFrame.setMaximized(true)
end
drawnow
tmp = get(hf,'Position');
hax = axes('YDir','reverse', 'Visible','off', 'Position',[0,0,1,1], ...
    'PlotBoxAspectRatio',tmp([3,4,4]), 'DataAspectRatio',[1,1,1]);
try addToolbarExplorationButtons(hf); set(hax.Toolbar,'Visible','off'); catch; end

im = read_im(frame_idx(1));
if strcmp(ext,'ptw')
    im = bpr(im, wnd, thr);
end

image('CData',im, 'CDataMapping','scaled');

roi_file = [fp1, 'crop_coords.mat']; % Файл будет лежать рядом с результатами

if isfile(roi_file)
    load(roi_file, 'pos'); % Если файл есть — просто загружаем координаты
else
    set(hf, 'Name','Set the area for the color limits')
    rrect = imrect(hax,[0.5+0.3*im_w, 0.5+0.3*im_h, 0.4*im_w, 0.4*im_h],...
        'PositionConstraintFcn',makeConstrainToRectFcn('imrect', [0.5,im_w+0.5], [0.5,im_h+0.5]));
    wait(rrect);
    roi = im(createMask(rrect));
    set(hax, 'CLim',[min(roi), max(roi)]);

    set(hf, 'Name','Set the crop rectangle')
    wait(rrect);
    pos = getPosition(rrect);
    
    save(roi_file, 'pos'); % Сохраняем только один раз, когда выбрали вручную
end

n1 = round(pos(1)+0.5);
n2 = round(pos(1)+pos(3)-0.5);
m1 = round(pos(2)+0.5);
m2 = round(pos(2)+pos(4)-0.5);
Nx = n2-n1+1;
Ny = m2-m1+1;
delete(hf)

n1 = round(pos(1)+0.5);
n2 = round(pos(1)+pos(3)-0.5);
m1 = round(pos(2)+0.5);
m2 = round(pos(2)+pos(4)-0.5);
Nx = n2-n1+1;
Ny = m2-m1+1;

% save('tmp.mat','n1','n2','m1','m2','Nx','Ny') %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% return
% %}
% load('tmp.mat')

ft = fspecial('gaussian', 2*ceil(2*sigma)+1, sigma/sqrt(2));

% ------------------------------ Main loop --------------------------------
Nf = numel(frame_idx);

for ind = 1 : Nf
    im = read_im(frame_idx(ind));
    im = im(m1:m2, n1:n2);
    if strcmp(ext,'ptw')
        im = bpr(im, wnd, thr);
    end
    
    T0 = f_T_obj(double(im));
    T = imfilter(T0,ft,'symmetric');
    
    tmp = 100/scale*diff(T,1,2);
    Tx = 0.5*(tmp(1:Ny-1,:) + tmp(2:Ny,:));
    
    tmp = -100/scale*diff(T,1,1);
    Ty = 0.5*(tmp(:, 1:Nx-1) + tmp(:, 2:Nx));
    
    Txy = sqrt(Tx.^2 + Ty.^2);
    Txy_mean = sum(sum(Txy))/((Nx-1)*(Ny-1))
    
    hf1 = figure;
    axes;
    x = (1:Nx)*scale;
    line('XData',x,'YData',T0(round(Ny/2),:),'Color','k','LineStyle','none','Marker','o')
    line('XData',x,'YData',T(round(Ny/2),:),'Color','r')

    return
    
    hf = figure('Colormap',jet(256));
    ha = axes('Box','on','Layer','top','TickDir','out','DataAspectRatio',[1,1,1],...
        'XLim',[0.5,Nx-0.5]*scale,'YLim',[0.5,Ny-0.5]*scale);
    him = image('XData',[1,Nx]*scale,'YData',[Ny,1]*scale,'CDataMapping','scaled');
    hcol = findobj(colorbar,'Type','axes');
    xlabel('\itx\rm, cm')
    ylabel('\ity\rm, cm')
    
    set(him,'CData',T)
    figure(hf)
    set(hcol,'TickDir','out')
    print(hf,sprintf('%sT',fp1),'-dpng','-r150')
    
    set(ha, 'XLim',[0.5,Nx-1.5]*scale,'YLim',[0.5,Ny-1.5]*scale)
    set(him,'XData',[1,Nx-1]*scale,'YData',[Ny-1,1]*scale)
    
    set(him,'CData',Tx)
    figure(hf)
    set(hcol,'TickDir','out')
    print(hf,sprintf('%sTx',fp1),'-dpng','-r150')
    
    set(him,'CData',Ty)
    figure(hf)
    set(hcol,'TickDir','out')
    print(hf,sprintf('%sTy',fp1),'-dpng','-r150')
    
    set(him,'CData',Txy)
    figure(hf)
    set(hcol,'TickDir','out')
    print(hf,sprintf('%sTxy',fp1),'-dpng','-r150')
end

delete([hf1,hf])
close_im();


% error('Done');

% catch ME
% %     fftw('wisdom',fft_wisdom);
% %     fftw('planner',fft_method);
%     close_im; %#ok<VUNUS>
% %     if ishghandle(pb_f), delete(pb_f); end
%     if ishghandle(hf), delete(hf); end
%     errordlg(ME.message);
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [read_im, close_im, Nf, w, h, ext, f_T_obj] = open_im(fp, fn, fpc,fnc)
% read_im(ind) - function handle to read ind frame
% close_im - function handle to close file / delete object
% Nf - total number of frames
% w, h - image width, height
% fp - path
% fn - file name (string) / file names (row cell)

k = strfind(fn,'.');
if isempty(k), error('The file is of unknown type'); end
ext = fn(k(end)+1 : end);
% ---------------------------- ptw file -----------------------------------
if strcmp(ext, 'ptw')
    fid = fopen([fp,fn]);
    if fid < 0, error('Failed to open the file'); end
    close_im = @() fclose(fid);
    sig = fread(fid, 3, '*char').';
    if ~strcmp(sig,'CED'), error('Incorrect file format'); end
    fseek(fid, 11, 'bof');
    mh_sz = fread(fid, 1, 'uint32');
    fh_sz = fread(fid, 1, 'uint32');
    fseek(fid, 27, 'bof');
    Nf = fread(fid, 1, 'uint32');
    fseek(fid, 64, 'bof');
    ptw_info.lens_name = fread(fid,20,'*char').';
    ptw_info.filter_name = fread(fid,20,'*char').';
    fseek(fid, 141, 'bof');
    ptw_info.emissivity = fread(fid,1,'float');
    ptw_info.T_background = fread(fid,1,'float'); % in K
    fseek(fid, 170, 'bof');
    ptw_info.transmission = fread(fid,1,'float');
    fseek(fid, 184, 'bof');
    ptw_info.T_atmosphere = fread(fid,1,'float'); % in K
    fseek(fid, 377, 'bof');
    w = fread(fid, 1, 'uint16');
    h = fread(fid, 1, 'uint16');
    fseek(fid, 407, 'bof');
    ptw_info.integration_time = round(1e6*fread(fid,1,'float'));
    
    [T,DL] = set_calib_file(fp, ptw_info, fpc,fnc);
    f_T_obj = get_T_obj_func(T, DL, ptw_info);
    
    offset = mh_sz - 2*h*w;
    f_sz = fh_sz + 2*h*w;
    im_sz = [w,h];
    read_im = @(ind) read_ptw(fid, offset, f_sz, ind, im_sz);
    return
end
% ---------------------------- read ptw file ------------------------------
function im = read_ptw(fid, offset, f_sz, ind, im_sz)
% Read *.ptw file
fseek(fid,  offset + ind*f_sz,  'bof');
im = fread(fid, im_sz, '*uint16').';
% ---------------------------- T_obj_func ---------------------------------
function f_T_obj = get_T_obj_func(T, DL, ptw_info)
% get T_obj(DL) (in °C) curve

F = fit(T, DL, 'a/(exp(b/(x+273.15))-1)+c', 'STartPoint',[1e8,3.3e3,1e3]);
C = coeffvalues(F);
a = C(1);
b = C(2);
c = C(3);
fb = F(ptw_info.T_background-273.15);
fa = F(ptw_info.T_atmosphere-273.15);
epsilon = ptw_info.emissivity;
tau = ptw_info.transmission;
a1 = a*epsilon*tau;
c1 = (tau-1)*fa + (epsilon-1)*tau*fb - c*epsilon*tau;
f_T_obj = @(f) b./log(1+a1./(f+c1))-273.15;
% ---------------------------- calib file ---------------------------------
function [T,DL] = set_calib_file(fp0, ptw_info, fp,fn)
% .exp file

fid_state = false;

try

if nargin < 3
    [fn,fp] = uigetfile([fp0,'.exp'],'Specify calibration file');
    if ~fn
        error('Calibration file wasn''t specified');
    end
end
ind = strfind(fn, '.');
if isempty(ind) || ~strcmp(fn(ind:end),'.exp')
    error('Wrong file extention');
end
fid = fopen(fullfile(fp,fn),'r');
if fid == -1
    error('Calibration file can''t be opened');
end
fid_state = true;
if ~strcmp(fread(fid,3,'*char').', 'EXP')
    error('Calibration file contains wrong data');
end

fseek(fid, 31, 'bof');
integration_time = fread(fid,1,'uint16');
if integration_time ~= ptw_info.integration_time
    error('Wrong integration_time');
end
fseek(fid, 141, 'bof');
lens_name = fread(fid,10,'*char').';
if ~strcmp(lens_name, ptw_info.lens_name(1:10))
    error('Wrong lens');
end
filter_name = fread(fid,20,'*char').';
if ~strcmp(filter_name, ptw_info.filter_name)
    error('Wrong filter');
end

fseek(fid, 265, 'bof');
N = fread(fid,1,'uint16'); % in bytes
DL = fread(fid,N,'float');
fseek(fid, 467, 'bof');
T = fread(fid,N,'float');

fclose(fid);

catch ME
    if fid_state
        fclose(fid);
    end
    rethrow(ME)
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function im = bpr(im, wnd, thr)
% Bad pixel replacement (median filter)
% im - image (grayscale)
% wnd (pix, odd) - window size
% thr (std) - threshold

ord = (wnd^2 + 1)/2;
dmn = true(wnd);
M = ordfilt2(im, ord, dmn, 'symmetric');
dM = im - M;
I = im < M; % uint
dM(I) = M(I) - im(I);
I = dM  >  (thr*1.4826) * ordfilt2(dM, ord, dmn, 'symmetric');
im(I) = M(I);