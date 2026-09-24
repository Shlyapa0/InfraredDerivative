function [read_im, close_im, Nf, w, h, ext] = open_im(fp, fn)
% read_im(ind) - function handle to read ind frame
% close_im - function handle to close file / delete object
% Nf - total number of frames
% w, h - image width, height
% fp - path
% fn - file name (string) / file names (row cell)

% TODO:
% 1) replace imformats with imfinfo and enable empty extension
% 2) test NumberOfFrames vs NumFrames
% 3) check if VideoReader with time selection instead of frame is faster
% 4) error after close - enable double cloe_im

% ---------------------------- Image set ----------------------------------
if iscell(fn)
    str = fn{1};   k = strfind(str,'.');
    if isempty(k), error('The files are of unknown type'); end
    ext = str(k(end)+1 : end);
    fmt = imformats(ext);
    if isempty(fmt) || ~fmt.isa([fp,str]), error('Incorrect file format'); end
    Nf = size(fn,2);
    for ind = 2 : Nf
        str = fn{ind};  k = strfind(str,'.');
        if isempty(k) || ~strcmp(str(k(end)+1 : end),  ext)
            error('The files must be of the same type');
        end
    end
    s = fmt.info([fp,fn{1}]);
    w = s.Width; h = s.Height;
    read_fcn = fmt.read;
    read_im = @(ind) read_fcn([fp,fn{ind}]);
    close_im = [];
    return
end

k = strfind(fn,'.');
if isempty(k), error('The file is of unknown type'); end
ext = fn(k(end)+1 : end);
% ---------------------------- ptw file -----------------------------------
if strcmp(ext, 'ptw')
    fid = fopen([fp,fn]);
    if fid < 0, error('Failed to open the file'); end
    sig = fread(fid, 3, '*char').';
    if ~strcmp(sig,'CED'), error('Incorrect file format'); end
    fseek(fid, 11, 'bof');
    mh_sz = fread(fid, 1, 'uint32');
    fh_sz = fread(fid, 1, 'uint32');
    fseek(fid, 27, 'bof');
    Nf = fread(fid, 1, 'uint32');
    fseek(fid, 377, 'bof');
    w = fread(fid, 1, 'uint16');
    h = fread(fid, 1, 'uint16');
    offset = mh_sz - 2*h*w;    f_sz = fh_sz + 2*h*w;    im_sz = [w,h];
    read_im = @(ind) read_ptw(fid, offset, f_sz, ind, im_sz);
    close_im = @() fclose(fid);
    return
end
% ---------------------------- One image ----------------------------------
fmt = imformats(ext);
if ~isempty(fmt)
    if ~fmt.isa([fp,fn]), error('Incorrect file format'); end
    Nf = 1;
    s = fmt.info([fp,fn{1}]);
    w = s.Width; h = s.Height;
    read_fcn = fmt.read;
    read_im = @() read_fcn([fp,fn]);
    close_im = [];
    return
end
% ------------------------------- Video -----------------------------------
try
    v = VideoReader([fp,fn]);
    Nf = v.NumberOfFrames;
%     Nf = v.NumFrames;
    w = v.Width; h = v.Height;
    read_im = @(ind) read(v,ind);
    close_im = @() delete(v);
catch
    error('Failed to open the file');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function im = read_ptw(fid, offset, f_sz, ind, im_sz)
% Read *.ptw file
fseek(fid,  offset + ind*f_sz,  'bof');
im = fread(fid, im_sz, '*uint16').';

