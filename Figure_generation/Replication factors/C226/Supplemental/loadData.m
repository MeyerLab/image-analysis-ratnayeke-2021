function [S] = loadData(conditions, dataDir)

%%% Analysis Options %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
setting.motherOption = 2;    %0:no gating 1:mothers 2:no mothers
setting.daughterOption = 2;  %0:no gating 1:daughters 2:no daughters
setting.quiescentAnalysis = 1;   %0:cycling cells 1:serum starved cells
setting.minTraceFrac = .5;
setting.nuc = 'CFP';
setting.cdk = '';
setting.apc = 'YFP';
setting.crl = '';
setting.sig = 'RFP';
setting.PCNA = '';

setting.IFoption = 1;        %0:No IF 1:IF
setting.IFlabel = 'IF_';
setting.poiCdk = 0;
setting.poiApc = 1;
setting.poiCrl = 0;
setting.poiG2 = 0;
setting.poiPCNA = 0;
startFrame = 1;

setting.saveDir = 'F:\Data\C-Cdt1\Figures\Paper\Replication factors\C226\';

setting.saveName = 'sensordata.mat';

%% PROCESS DATA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if setting.quiescentAnalysis
    setting.motherOption = 2;
    setting.daughterOption = 2;
end

%%% Load data header
load([dataDir,'settings_live.mat'],'names');
names = names(2,:);

%%% Find conditions
allNames = conditions(:,1);
[~,uidx] = unique(allNames,'first');
uniqueNames = allNames(sort(uidx));
uniqueCondnum = numel(uniqueNames);
condNum = size(conditions,1);

%% PROCESS CONDITION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
S = struct('traceData', [], 'traceStats', [], 'motherStats', [], 'IFdata', [], 'wellindex', [], 'cellID', [], 'shot', [], 'jitters', [], 'pos', []);
for i = 1:uniqueCondnum
    S(i).traceData = [];
    S(i).traceStats = [];
    S(i).motherStats = [];
    S(i).IFdata = [];
    %Traces(i).IFjitter = [];
    S(i).wellindex = [];
    S(i).cellID = [];
    S(i).shot = [];
    condRow = find(ismember(conditions(:,1),uniqueNames{i}));
    %%% Load data from all sites of condition
    for c = condRow'
        rowMat = cell2mat(conditions(c,2));
        colMat = cell2mat(conditions(c,3));
        siteMat = cell2mat(conditions(c,4));
        for row = rowMat
            for col = colMat
                for site = siteMat
                    shot = [num2str(row),'_',num2str(col),'_',num2str(site)];
                    if exist([dataDir,'traceData_',shot,'.mat']) && (~setting.IFoption || exist([dataDir,setting.IFlabel,shot,'.mat']))
                        [traceDatatemp,traceStatstemp,motherStatstemp,IFdatatemp,jitters,samplecellsID] = ...
                            gathertracedata_1_rev05_NR(dataDir,shot,setting.motherOption,setting.daughterOption,setting.IFoption,setting.IFlabel);
                        try
                            S(i).traceData = [S(i).traceData; traceDatatemp];
                        catch
                            keyboard
                        end
                        S(i).traceStats = [S(i).traceStats; traceStatstemp];
                        S(i).motherStats = [S(i).motherStats; motherStatstemp];
                        S(i).IFdata = [S(i).IFdata; IFdatatemp];
                        S(i).cellID = [S(i).cellID; samplecellsID];
                        wellindexTemp = ones(size(traceDatatemp,1),3);
                        wellindexTemp(:,1) = wellindexTemp(:,1)*row;wellindexTemp(:,2) = wellindexTemp(:,2)*col;wellindexTemp(:,3) = wellindexTemp(:,3)*site;
                        S(i).wellindex = [S(i).wellindex; wellindexTemp];
                        S(i).shot = [S(i).shot; repmat({shot},size(traceDatatemp,1),1)];
                        jittersTemp = repmat(reshape(jitters, [1 size(jitters,1) 2]),size(traceDatatemp,1),1);
                        S(i).jitters = [S(i).jitters; jittersTemp];
                        S(i).pos = [S(i).pos; traceDatatemp(:,:,1:2)];
                    end
                end
            end
        end
    end
    %% Load IF data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if setting.IFoption
        load([dataDir, 'settings_live_IF.mat'],'header');
        IFnames = header(2,:);
        
        S(i).IFarea = S(i).IFdata(:, find(ismember(IFnames,'nuclear area')));
        S(i).DAPI1 = S(i).IFdata(:, find(ismember(IFnames,'1_DAPI_mean')));
        S(i).FarRed1 = S(i).IFdata(:, find(ismember(IFnames,'1_FarRed_mean')));
        S(i).FarRed1cyt = S(i).IFdata(:, find(ismember(IFnames,'1_FarRed_cyto ring')));
      
        S(i).YFP2 = S(i).IFdata(:, find(ismember(IFnames,'2_YFP_mean')));
        S(i).YFP2cyt = S(i).IFdata(:, find(ismember(IFnames,'2_YFP_cyto ring')));

        S(i).YFP3 = S(i).IFdata(:, find(ismember(IFnames,'3_YFP_mean')));
        S(i).RFP3 = S(i).IFdata(:, find(ismember(IFnames,'3_RFP_mean')));

                
        S(i).dna = S(i).DAPI1 .* S(i).IFarea;
        S(i).x = S(i).IFdata(:, find(ismember(IFnames,'x')));
        S(i).y = S(i).IFdata(:, find(ismember(IFnames,'y')));
        
    end
    %% Extract nuclear channels
    S(i).area = S(i).traceData(:,:,ismember(names,'nuclear area'));
    S(i).nucMean = S(i).traceData(:,:,ismember(names,[setting.nuc '_mean']));
    S(i).mass = S(i).area.*S(i).nucMean;
    S(i).massNorm = S(i).mass./repmat(max(S(i).mass,[],2),1,size(S(i).area,2));
    S(i).POI(:, 1) = S(i).traceStats(:,1);
    
    %% Gate on length
    numFrames = size(S(i).traceData,2);
    minLengthTrace = ceil(numFrames*setting.minTraceFrac);
    if setting.quiescentAnalysis
        minLengthTrace =  (numFrames-startFrame)*setting.minTraceFrac;
    end
    S(i).traceStats(:,5) = findInMat(~isnan(S(i).area));
    badlengths = S(i).traceStats(:,2) - S(i).traceStats(:,5) < minLengthTrace; %| sensor(i).motherStats(:,3)<5;
    S(i)=gateout_all(S(i),~badlengths);
    
    %% Gate nuclear
    noiseThresh = .07; %(.07)
    badNoise = gatenoisy(S(i).massNorm, S(i).traceStats, setting.daughterOption, setting.quiescentAnalysis, noiseThresh, 4,4);
    %     clear  highNoise;
    %     %%% Gate on absolute change
    %     for n = 1:size(S(i).massNorm,1)
    %         highNoise(n,1) = any(abs(diff(S(i).massNorm(n,:))) > .25);
    %     end
    S(i) = gateout_all(S(i),~(badNoise));
    
    %% Extract and gate cdk %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if ~isempty(setting.cdk)
        S(i).cdkNuc = S(i).traceData(:,:,ismember(names,[setting.cdk '_mean']));
        S(i).cdkCyt = S(i).traceData(:,:,ismember(names,[setting.cdk '_cyto ring']));
        S(i).cdkLocalBg = S(i).traceData(:,:,ismember(names, [setting.cdk '_block bg']));
        
        maxThresh = 200; %threshold above which max of each trace must be  %150
        noiseThresh = .5;%0.20; %threshold rate of DHBratio change (not absolute) above which trace is considered noisy
        smoothWindow = 5;
        [S(i).cdk,badTracesCdk] = gate_Cdk2_NR(S(i).cdkNuc,S(i).cdkCyt,maxThresh,noiseThresh,smoothWindow);
        %sensor(i).cdk = sensor(i).cdkCyt./sensor(i).cdkNuc;
        S(i) = gateout_all(S(i),~badTracesCdk);
    end
    
    %% Extract and gate apc %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if ~isempty(setting.apc)
        S(i).apcNuc = S(i).traceData(:,:,ismember(names,[setting.apc '_mean']));% - S(i).apcLocalBg;
        %         S(i).apcNuc = correctBlankFrame(S(i).apcNuc, S(i).shot, 20:72, -5);
        %         S(i).apcNuc = fillTraceVals(S(i).apcNuc, S(i).traceStats, 5);
        
        %%% Gate cell traces
        if setting.quiescentAnalysis
            % Quiescent
            noiseThresh = 200;
            maskTrace = [];
            meanWindow = 35:45;
            lowThresh = 20;
            noiseMask = ones(1,numFrames-1);
            noiseMask(maskTrace)=0;
            clear highTracestart highNoise;
            for n = 1:size(S(i).apcNuc,1)
                highTracestart(n,1) = S(i).apcNuc(n,S(i).traceStats(n,1)) > lowThresh;
                highNoise(n,1) = any(abs(diff(S(i).apcNuc(n,:))) > noiseThresh & noiseMask);
            end
            highMean = nanmean(S(i).apcNuc(:,meanWindow),2) > lowThresh;
            %S(i).apcBadTraces = highTracestart | highMean; % Don't gate out weird apc traces
            S(i) = gateout_all(S(i),~(highNoise | highMean | highTracestart));
            
        else
            % Cycling
            minMaxThresh = [2000000 -200];
            minMaxNoise = [-500 500];
            traceGem = S(i).apcNuc;
            buff = 5;
            postMitosis = 0;
            [badTracesApc] = gateSigTraces(traceGem, S(i).traceStats, buff, postMitosis, minMaxThresh, minMaxNoise);
            S(i) = gateout_all(S(i),~(badTracesApc));
        end
        
        %%% Transform data
        S(i).apcArea = (S(i).apcNuc).*S(i).area;
        S(i).apcAreaSmooth = NaN*ones(size(S(i).apcNuc));
        if ~setting.quiescentAnalysis
            S(i).apcNorm = (S(i).apcNuc-repmat(min(S(i).apcNuc,[],2),1,size(S(i).apcNuc,2)))...
                ./repmat(max(S(i).apcNuc,[],2),1,size(S(i).apcNuc,2));
            S(i).apcNormM = NaN*ones(size(S(i).apcNuc));
            
            for n = 1:size(S(i).apcArea,1)
                S(i).apcAreaSmooth(n,:) = nansmooth(S(i).apcArea(n,:),3);
                mitFrame = S(i).POI(n,1);
                if ~isnan(mitFrame) & mitFrame - 10 > 0
                    S(i).apcNormM(n,:) =  (S(i).apcNuc(n,:) - min(S(i).apcNuc(n,mitFrame - 10:end)));
                    S(i).apcNormM(n,:) = S(i).apcNormM(n,:)/max(S(i).apcNormM(n,:));
                else
                    S(i).apcNormM(n,:) =  S(i).apcNorm(n,:);
                end
            end
        end
        
        %  %%% Find APC inactivation
        if setting.poiApc
            if setting.quiescentAnalysis
                [S(i).POI(:,2), badTracesAPC] = findAPCInact(S(i).apcNuc, S(i).traceStats, ...
                    struct('postBuffer',5,'smooth',5,'cycling',0,...
                    'buff',1,'thresh',1,'preBuffer',1,'lowThresh',15, 'increase',5*1,'trunc',50, 'medfilt',0,'early', 40,'debug',0));
            else
                [S(i).POI(:,2), badTracesAPC] = findAPCInact_C136(S(i).apcNormM, S(i).traceStats, ...
                    struct('postBuffer',5,'smooth',3,'cycling',1,...
                    'buff',1,'thresh',.0025,'preBuffer',5,'lowThresh',.1, 'increase',.015,'trunc',.5, 'medfilt',0,'early', 10));
            end
            %S(i) = gateout_all(S(i),~(badTracesAPC));
            %S(i).apcBadTraces = S(i).apcBadTraces | badTracesAPC;
        end
        
        
    end
    
    %% Extract and gate crl
    if ~isempty(setting.crl)
        S(i).crlNuc = S(i).traceData(:,:,ismember(names,[setting.crl '_mean']));% - S(i).crlLocalBg;
%         S(i).crlNuc = correctBlankFrame(S(i).crlNuc, S(i).shot, 2:30, -50);
%         S(i).crlNuc = fillTraceVals(S(i).crlNuc, S(i).traceStats, 5);
        S(i).crlArea = (S(i).crlNuc).*S(i).area;
        
        %%% Gate out traces
        noiseThresh = 20000;
        maskTrace = [];
        %meanWindow = 20:30;
        lowThresh = 100;
        noiseMask = ones(1,numFrames-1);
        noiseMask(maskTrace)=0;
        clear lowTracestart highNoise;
        for n = 1:size(S(i).crlNuc,1)
            lowTracestart(n,1) = S(i).crlNuc(n,S(i).traceStats(n,1)) < lowThresh;
            highNoise(n,1) = any(abs(diff(S(i).crlNuc(n,:)))>noiseThresh & noiseMask);
        end
        %lowMean = nanmean(S(i).crlNuc(:,meanWindow),2) < lowThresh;
        lowMax = max(S(i).crlNuc,[],2) < lowThresh;
        %S(i).crlExpress = ~lowMax;
        S(i) = gateout_all(S(i),~( highNoise | lowMax));
        
        %%% Transform traces
        S(i).crlNorm = NaN*ones(size(S(i).crlNuc));
        S(i).crlAreaNorm = NaN*ones(size(S(i).crlNuc));
        S(i).crlAreaSmooth = NaN*ones(size(S(i).crlNuc));
        S(i).crlDiff = NaN*ones(size(S(i).crlNuc));
        for n = 1:size(S(i).crlArea,1)
            S(i).crlNorm(n,:) =  S(i).crlNuc(n,:)./max(S(i).crlNuc(n,1:end-1));
            S(i).crlAreaNorm(n,:) =  S(i).crlArea(n,:)./max(S(i).crlArea(n,1:end-1));
            S(i).crlNormSmooth(n,:) = nansmooth(S(i).crlNorm(n,:), 5);
            S(i).crlDiff(n,:) = gradient(S(i).crlAreaSmooth(n,:));
            
            if ~setting.quiescentAnalysis
                startFrame = S(i).POI(n,1);
                if ~isnan(startFrame) & startFrame +1 <= numFrames & ~setting.quiescentAnalysis
                    S(i).crlNormPostM(n,:) =  S(i).crlArea(n,:)./max(S(i).crlArea(n,startFrame:end-1));
                elseif ~setting.quiescentAnalysis
                    S(i).crlNormPostM(n,:) =  S(i).crlAreaNorm(n,:);
                end
            end
        end
        
        %%% Find crl inactivation
        if setting.poiCrl
            S(i).POI(:,3) = findCRL4Act(S(i).crlAreaNorm,S(i).traceStats, ...
                struct('cycling',~setting.quiescentAnalysis,'low',.1,'smooth',5, ...
                'firstD',0,'secD',-.005,'early', 30,'falseCall', .8,'buff',0, 'postBuffer', 4,'decrease', .03*4,'debug',0));
            
            %S(i).POI(:,4) = aprioriCRL4act(S(i).crl4Activity, S(i).POI(:,3), .008, 5, S(i).crlSmooth);
            if setting.poiG2
                S(i).POI(:,4) =findCRLInact_C111(S(i).crlAreaNorm, S(i).traceStats,S(i).POI(:,3), ...
                    struct('postBuffer',5,'smooth',3,'early',3,...
                    'buff',3,'thresh',.1,'preBuffer',5,'lowThresh',.1,'increase',.05,'trunc',.5,'medfilt',0));
            end
            S(i).crlNormAct = NaN*ones(size(S(i).crlNuc));
%             for n = 1:size(S(i).crlArea,1)
%                 if ~isnan(S(i).POI(n,3))
%                     S(i).crlNormAct(n,:) =  S(i).crlNuc(n,:)/S(i).crlNuc(n,S(i).POI(n,3));
%                     if(log2(S(i).YFP2(n)) > 6 | log2(S(i).dna) < 22)
%                         S(i).POI(n,3) = NaN;
%                     end
%                 else
%                     S(i).crlNormAct(n,:) = S(i).crlNorm(n,:);
%                 end
%             end
        end
        
    end
    
    %% Extract and gate sig
    if ~isempty(setting.sig)
        S(i).sigNuc = S(i).traceData(:,:,ismember(names,[setting.sig '_mean']));
        S(i).sigArea = (S(i).sigNuc).*S(i).area;
        
        % Gate out traces on noise and misexpression
        noiseThresh = 20000;
        maskTrace = [];
        %meanWindow = 70:100;
        lowThresh = 20;
        noiseMask = ones(1,numFrames-1);
        noiseMask(maskTrace)=0;
        clear lowTracestart highNoise;
        for n = 1:size(S(i).sigNuc,1)
            highNoise(n,1) = any(abs(diff(S(i).sigNuc(n,:)))>noiseThresh & noiseMask);
        end
        %lowMean = nanmean(S(i).sigNuc(:,meanWindow),2) < lowThresh;
        lowMax = max(S(i).sigNuc,[],2) < lowThresh;
        S(i) = gateout_all(S(i),~( highNoise));
        S(i).sigExpress = ~lowMax;
        
        % Transform data
%         for n = 1:size(S(i).sigArea,1)
%             ignore_norm = 5;
%             S(i).sigNorm(n,:) =  S(i).sigArea(n,:)./max(S(i).sigArea(n,ignore_norm:end-1));
%             S(i).sigSmooth(n,:) = nansmooth(S(i).sigArea(n,:), 5);
%             S(i).sigNormSmooth(n,:) = nansmooth(S(i).sigNorm(n,:), 5);
%             S(i).sigDiff(n,:) = gradient(S(i).sigSmooth(n,:));
%         end
        
    end
    
    
    %% Extract and gate PCNA
    if ~isempty(setting.PCNA)
        S(i).pcnaNuc = S(i).traceData(:,:,ismember(names,'PCNA mean'));
        
        % Gate out traces on noise and misexpression
        noiseThresh = 20000;
        maskTrace = [];
        meanWindow = 70:100;
        lowThresh = 200;
        noiseMask = ones(1,numFrames-1);
        noiseMask(maskTrace)=0;
        clear lowTracestart highNoise;
        for n = 1:size(S(i).pcnaNuc,1)
            highNoise(n,1) = any(abs(diff(S(i).pcnaNuc(n,:)))>noiseThresh & noiseMask);
        end
        lowMean = nanmean(S(i).pcnaNuc(:,meanWindow),2) < lowThresh;
        %lowMax = max(S(i).pcnaNuc,[],2) < lowThresh;
        S(i) = gateout_all(S(i),~( lowMean | highNoise));
        %         S(i) = gateout_all(S(i),~( highNoise));
        %         S(i).pcnaExpress = ~lowMax;
        
        % load data
        S(i).filterIntensity = S(i).traceData(:,:,ismember(names,'Filter mean'));
        S(i).filterArea = S(i).traceData(:,:,contains(names,'Filter Masked area'));
        S(i).filterMaskIntensity = S(i).filterArea.*S(i).traceData(:,:,contains(names,'Filter Masked mean'));
        
        S(i).varIntensity = S(i).traceData(:,:,ismember(names,'Variance mean'));
        S(i).varStd = S(i).traceData(:,:,ismember(names,'Variance std'));
        %         S(i).varIntensityNorm = S(i).varIntensity./repmat(nanmean(S(i).pcnaNuc(:,meanWindow),2),[1 size(S(i).pcnaNuc,2)]);
        S(i).varIntensityNorm = S(i).varIntensity-repmat(min(S(i).varIntensity,[],2),[1 size(S(i).pcnaNuc,2)]);
        S(i).varArea = S(i).traceData(:,:,contains(names,'Variance Masked area'));
        S(i).varMaskIntensity = S(i).varArea.*S(i).traceData(:,:,contains(names,'Variance Masked mean'));
        %S(i).varMaskIntensityNorm = S(i).varMaskIntensity./repmat(nanmean(S(i).pcnaNuc(:,meanWindow),2),[1 size(S(i).pcnaNuc,2)]);
        
        if setting.poiPCNA
            S(i).filterPOI = getPCNAstart_C117(S(i).filterArea(:,:,2),S(i).traceStats,10,10);
            % S(i).filterPOI = getPCNAstart_C114_intensity(S(i).varIntensityNorm(:,:),S(i).traceStats,10,20);
            
        end
    end
    
    
    
end

%% Extra transformations
for i = 1:length(S)
    
    if setting.IFoption
        S(i).jitterX = S(i).IFdata(:, find(ismember(IFnames,'jitterX')));
        S(i).jitterY = S(i).IFdata(:, find(ismember(IFnames,'jitterY')));
        S(i).fixedRow = S(i).IFdata(:, find(ismember(IFnames,'row')));
        S(i).fixedCol = S(i).IFdata(:, find(ismember(IFnames,'col')));
        S(i).fixedSite = S(i).IFdata(:, find(ismember(IFnames,'fixed site')));
    end
end

save([setting.saveDir setting.saveName],'S','-v7.3');


end

%% Extra code
%     S(i).traceData = S(i).traceData(:,1:end-1,:);
%     S(i).traceStats(S(i).traceStats == 156) = 155;
%     S(i).traceStats(:,3) = S(i).traceStats(:,2) - S(i).traceStats(:,1) + 1;
% Median filter to get rid of single frame noise
%     for numcell = 1:size(S(i).apcNuc,1)
%         S(i).apcNuc_filt(numcell,:) = S(i).apcNuc(numcell,:);
%         ind = ~isnan(S(i).apcNuc_filt(numcell,:));
%         S(i).apcNuc_filt(numcell,ind) = medfilt1(S(i).apcNuc_filt(numcell,ind),3);
%     end

%         S(i).crlLocalBg = S(i).traceData(:,:,ismember(names, [setting.crl '_block bg']));
%         [S(i).crlLocalBg, badBg] = fillTraceVals(S(i).crlLocalBg, S(i).traceStats, 5);
%         S(i).crlNuc = correctBlankFrame(S(i).crlNuc, S(i).shot, 10:40, -10);
%         S(i).crlNuc = fillTraceVals(S(i).crlNuc, S(i).traceStats, 5);
%         S(i).crlNuc(S(i).crlNuc <=0) = .01;
%         S(i).crl4Act = calcCRL4ActivityCycling_E1092(S(i).crlArea,S(i).traceStats,S(i).POI(:,3),...
%             struct('manualk_syn',NaN,'buffer',5,'k_deg', 0, 'k_mult',10, 'smooth',5));
%         S(i).crl4Act(S(i).crl4Act <= 0) = 1e-4;
%         S(i).logCrl4Act = log(S(i).crl4Act);
