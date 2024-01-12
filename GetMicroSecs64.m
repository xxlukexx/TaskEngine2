function [ microSecsOut ] = GetMicroSecs64
% GetMicroSecs64 - a wrapper for GetSecs, which returns the time in
% microseconds, as a 64-bit unsigned integer. Useful for interoperability
% with the Tobii SDK, which returns timestamps in uint64 format. 

microSecsOut = int64(GetSecs * 1000000);
end

