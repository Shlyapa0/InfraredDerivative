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