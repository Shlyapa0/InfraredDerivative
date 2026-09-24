function bulk_IR_der(frameNumbers, outputFile)
scale = 6/182.18;
if ischar(outputFile)
    fid = fopen(outputFile, 'at');
else
    print("No output file provided, results will not be saved")
end

for k = 1:numel(frameNumbers)
    i = frameNumbers(k);
    Txy_mean = IR_der_v2("FileName", 'Cap1.ptw', "FilePath", 'C:\Users\User\Downloads\',"FrameIndex", i, "Scale", scale);
    if fid ~= -1 
        fprintf(fid, '%d; %.6f\n', i, Txy_mean); 
    end
end

if fid ~= -1 
    fclose(fid); 
end

end