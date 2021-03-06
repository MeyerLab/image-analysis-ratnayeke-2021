function [ riseTime, badTraces] = findAPCInact( apcTrace, traceStats, settings )
%
[sampleSize,traceLength] = size(apcTrace);
riseTime = ones(sampleSize,1)*NaN;
riseTimeRel = ones(sampleSize,1)*NaN;
firstFrame = ones(sampleSize,1)*NaN;
lastFrame = ones(sampleSize,1)*NaN;
fullTraceStore = ones(sampleSize,traceLength)*NaN;
badTraces = false(sampleSize,1);

for i=1:size(apcTrace, 1)
    trace = apcTrace(i,:);
    trace = trace - min(trace);
    fullTraceStore(i,:) = trace;
    if settings.cycling == 1
        mitosisFrame = traceStats(i, 1);
        %startFrame = mitosisFrame + settings.buff;        
        startFrame = find(trace < settings.trunc & 1:length(trace) >= mitosisFrame+settings.buff,1,'first');   
        if isempty(startFrame)
            continue;
        end
        endFrame = traceStats(i,2);
    else
        %startFrame = traceStats(i,5);
        startFrame = find(trace < settings.trunc,1,'first');
        endFrame = traceStats(i,2);
    end
    firstFrame(i) = startFrame;
    lastFrame(i) = endFrame;
    
    trace = trace(startFrame:endFrame);
    trunc = find(trace > settings.trunc,1,'first');
    if ~isempty(trunc)
        trace = trace(1:trunc);
    end
    
    if length(trace) > settings.postBuffer
        %trace = trace - min(trace);
        signal = nansmoothm(trace, settings.smooth,'sgolay');
        
        %%% build risetime filter %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% general requirements
        numFrames = size(trace,2);
        presentHeight = zeros(1,numFrames);
        minFutureHeight = zeros(1,numFrames);
        futureHeightInc = zeros(1,numFrames);
        allSlope = zeros(1,numFrames);
        early = zeros(1,numFrames);
        sigSlope = gradient(signal);
        for j = 1:numFrames - settings.postBuffer
            presentHeight(j) = signal(j) < settings.lowThresh; %default 0.05
            minFutureHeight(j) = min(signal(j+1:j+settings.postBuffer)) > signal(j);
            futureHeightInc(j) = signal(j+settings.postBuffer) > signal(j) + settings.increase; %default 0.1
            %allSlope = sum(sigSlope(j:j+settings.postBuffer) > settings.thresh) >= settings.postBuffer;
            allSlope(j) = sum(sigSlope(j+1:j+settings.postBuffer) > settings.thresh) >= settings.postBuffer- round(settings.postBuffer * .1);
            if settings.cycling
                early(j) = j + settings.buff > settings.early;
            else
                early(j) = j + startFrame -1 > settings.early;
            end
        end
        gate = presentHeight & minFutureHeight & futureHeightInc & allSlope & early;
        
        filterScore = sigSlope;
        %         sigFwdSlope = 10*getslope_forward_avg(signal, 1:settings.postBuffer);
        %         sigTime = (1:length(signal))/traceLength;
        %         filterScore = 2*sigFwdSlope - 1*signal + sigTime + 1;
        filterScore = filterScore.*gate;
        if settings.medfilt
            filterScore = medfilt1(filterScore,settings.medfilt);
        end
        %tempsearch=find(sig_fwdslope>0.05 & abs(signal)<0.03,1,'last');
        tempSearch=find(filterScore > settings.thresh,1,'first');
        
        if ~isempty(tempSearch) %&& filtermax>0
            while tempSearch > 2 && filterScore(tempSearch-1) > settings.thresh
                tempSearch = tempSearch-1;
            end
            riseTimeRel(i) = tempSearch;
            riseTime(i) = tempSearch + startFrame-1; %return absolute POI rather than relative to mitosis
        elseif max(signal(settings.preBuffer:end - settings.postBuffer))<settings.lowThresh
            riseTime(i)=NaN;
        else
            badTraces(i) = 1;
        end
    else
        trace = apcTrace(i,:);
        signal = trace;
        filterScore = [];
        badTraces(i) = 1;
    end
    
   if any(i == []) & settings.debug  
        clf
        figure(1),
        subplot(4,1,1)
        plot(apcTrace(i,:)), hold on
        %ylim([-0.1 1]);
        subplot(4,1,2)
        plot(trace), hold on
        plot(signal,'--')

        %ylim([0 1]);
        if ~isnan(riseTimeRel(i))
            scatter(riseTimeRel(i), trace(riseTimeRel(i)),100,'r.');
            hold off
            subplot(4,1,1)
            scatter(riseTime(i),apcTrace(i,riseTime(i)))
            hold off
        end
        subplot(4,1,3)
        plot(sigSlope)
        hline(settings.thresh);
        if  length(trace) > settings.postBuffer
            subplot(4,1,4)
            plot(filterScore);
            hline(settings.thresh);
        end
        keyboard;
   end
end

%%% debug %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if settings.debug
    traceIDs=[1:96];
    ylims=[0 1];
    POIs = {riseTime};
    POIdisplay(traceIDs,fullTraceStore, firstFrame, lastFrame,badTraces,ylims, POIs);
    keyboard;
end