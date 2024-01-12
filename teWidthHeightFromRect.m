function [w, h] = teWidthHeightFromRect(rect)

    w = rect(3) - rect(1);
    h = rect(4) - rect(2);

end