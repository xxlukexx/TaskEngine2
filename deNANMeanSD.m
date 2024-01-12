function [m ,sd] = deNANMeanSD(x)

    n = isnan(x);
    
    m = mean(x(~n));
    sd = std(x(~n));

end