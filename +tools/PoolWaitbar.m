classdef PoolWaitbar < handle
% PoolWaitbar Graphically monitors progress aggregated over multiple
% workers.
%
%   POOLWAITBAR(N,X) creates and displays the waitbar with the initial 
% message 'X' over a total workload N. It is a modified version of the 
% built-in matlab function WAITBAR, but allows multiple workers to 
% independently update the bar.
%
% Example use:
% wb = PoolWaitbar(10)
% parfor 1:10
%   % Parallel work
%   increment(wb)
% end
% delete(wb)
%
% Created by:
% Edric Ellis, 2019
%
% Implemented by:
% Simon Andreas Bjørn, 2023
    properties(SetAccess = immutable, GetAccess = private)
        Queue
        N
    end
    properties (Access = private, Transient)
        ClientHandle = []
        Count = 0
    end
    properties (SetAccess = immutable, GetAccess = private, Transient)
        Listner = []
    end

    methods (Access = private)
        function localIncrement(h)
            h.Count = h.Count + 1;
            waitbar(h.Count / h.N, h.ClientHandle)
        end
    end
    methods
        function h = PoolWaitbar(N, message)
            if nargin < 2
                message = 'Waiting on process pool...';
            end
            h.N = N;
            h.ClientHandle = waitbar(0, message);
            h.Queue = parallel.pool.DataQueue;
            h.Listner = afterEach(h.Queue, @(~) localIncrement(h));
        end
        function increment(h)
            send(h.Queue, true);
        end
        function delete(h)
            delete(h.ClientHandle);
            delete(h.Queue);
        end
    end
end