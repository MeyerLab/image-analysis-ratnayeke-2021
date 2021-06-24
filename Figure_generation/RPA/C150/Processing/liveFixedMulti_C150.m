function liveFixedMulti_C150( row,col,site, debug_mode, logFolder, filePrefix)
% row=2;
% col=2;
% site=1;
% debug_mode = 0;
% logFolder = 'test\';
% filePrefix = 'Worker1';
 settings.debug_mode = debug_mode;

%% SETTINGS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Paths
settings.data_path = 'F:\Data\C-Cdt1\C150-live\Data\';
settings.IF_imagesessions = {'I:\4TB3\Data\C150-IF1\'};
settings.live_imagepath = 'I:\4TB3\Data\C150-live\Raw\';
settings.bgcmospath = 'F:\MATLAB\BGimages\IX_XL\cmosoffset_bin1.mat';
settings.crop_save = 'I:\4TB3\Data\C150-IF1crop\';
settings.logFile = [logFolder filePrefix '_log.txt'];
settings.errorFile = [logFolder filePrefix '_error.txt'];

%%% General parameters
settings.magnification = 20; %10 = 10x or 20 = 20x
settings.binsize = 2; %1 = bin 1 or 2 = bin 2
settings.postbin = [.5]; %0 for no bin, number for scaling factor;
settings.match10x20x = 1;
settings.scaleLive = 1;
settings.signals = {{'DAPI_','YFP_','FarRed_'}};
settings.nucLive = 'CFP_';

%%% Quantification parameters
settings.bias = {[1 1 1 ]};
settings.biasall = {[0 0 0]};
settings.sigblur = {[0 0 0 ]};
settings.signal_foreground = {[1 1 1 ]};
settings.ringcalc = {[1 1 1 ]};
settings.ringthresh = {[100 100 100]};
settings.punctacalc = {[0 0 0 ]};
settings.punctaThresh = {[0 0 100]};
settings.localbg = {[1 1 1]};
settings.minringsize = 100;
settings.bleedthrough = {[0 0 0 ]};
settings.bleedthroughpth = {{'' '' '' }};
settings.bgcmoscorrection = 1; %1 = correct for shading; 0 = dont correct for shading;
settings.bgsubmethod = {{'global nuclear','global nuclear', 'global nuclear'}}; %'global nuclear','global cyto','tophat','semi-local nuclear'
settings.bgperctile = 50;
settings.frameIF=1;

%%% Segmentation parameters
settings.segmethod = {'concavity', 'concavity'}; %'log' or 'single' or 'double'
settings.nucr = 12; %10x bin1 = 12 and 20x bin2 = 12
settings.debrisarea = 100; %100
settings.boulderarea = 1500; %1500
settings.blobthreshold = -0.03;
settings.blurradius = 3;
settings.soliditythresh = 0.80;
settings.compression = 4;
settings.badFrameCheck = .25; %0 for no check

%%% Tracking parameters
settings.distthresh = 3*settings.nucr;
settings.arealowthresh = -.5;
settings.areahighthresh = .5;


%% PROCESS IMAGES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
shotLive=[num2str(row),'_',num2str(col),'_',num2str(site)];
if exist([settings.data_path,'tracedata_',shotLive,'.mat']) & ~exist([settings.data_path,'IF_',shotLive,'.mat'])
    
    %%% Setup time output
    timetotal=tic;
    if ~exist(logFolder,'dir')
        mkdir(logFolder)
    end
    errorFileID = fopen(settings.errorFile,'a+');
    logFileID = fopen(settings.logFile,'a+');
    fprintf(logFileID, '%s : Shot %02d_%02d_%02d started ...\r\n',datestr(now,'HH:MM:SS'),row,col,site);
    
    try
        %%% Load live data
        rawLiveDir = [settings.live_imagepath,shotLive,'\',shotLive,'_'];
        live = load([settings.data_path,'tracedata_',shotLive,'.mat'],'tracedata','jitters');
        [live.totalcells,live.totalframes,~]=size(live.tracedata);
        
        %%% Load previous image and mask
        live.rawprev=single(imread([rawLiveDir,settings.nucLive,num2str(live.totalframes),'.tif']));

        [live.prevheight,live.prevwidth]=size(live.rawprev);
        live.nuc_mask_prev=threshmask(live.rawprev,3);
        
        
        %%% Process fixed image
        if settings.match10x20x
            numsites=4;
            [upperleft,upperright,lowerleft,lowerright]=siteChange(numsites,site);
            
            %%% Process each 20x image for the 10x live frame
            IFdata_upperleft = processImage(row, col, site, upperleft, live, settings, logFileID, errorFileID);
            IFdata_upperright = processImage(row, col, site, upperright, live, settings, logFileID, errorFileID);
            IFdata_lowerleft = processImage(row, col, site, lowerleft, live, settings, logFileID, errorFileID);
            IFdata_lowerright = processImage(row, col, site, lowerright, live, settings, logFileID, errorFileID);
            
            %%% Collect data
            IFdata = ones(size(IFdata_upperleft))*NaN;
            IFdata = addGoodRows(IFdata,IFdata_upperleft);
            IFdata = addGoodRows(IFdata,IFdata_upperright);
            IFdata = addGoodRows(IFdata,IFdata_lowerleft);
            IFdata = addGoodRows(IFdata,IFdata_lowerright);
        else
            %%% Process fixed image for live frame
            IFdata =  processImage(row, col, site, site, live, settings, logFileID, errorFileID);
        end
        
        %%% Save data and settings
        save([settings.data_path,'IF_',shotLive,'.mat'],'IFdata');
        fixed = {'x','y','nuclear area','jitterX','jitterY','row','col','fixed site'};
        varInd = {{[1 1 1 1], [1 1]}, {[1 1 1 1], [1 1]},settings.localbg, settings.ringcalc};
        header = output_names_universal(fixed,{'mean','median','localbg','cyto ring'},varInd, settings.signals);
        save([settings.data_path,'settings_IF.mat'],'settings','header'); %will overwrite with the most recent
        
        elapsedTime = toc(timetotal);
        fprintf(logFileID, '%s : Shot %02d_%02d_%02d finished in %05.1f sec\r\n\r\n',datestr(now,'HH:MM:SS'),row,col,site,elapsedTime);
    catch ME
        elapsedTime = toc(timetotal);
        fprintf(errorFileID, '%s : ERRROR Shot %02d_%02d_%02d after %05.1f sec\r\n',datestr(now,'HH:MM:SS'),row,col,site,elapsedTime);
        fprintf(errorFileID,'%s \r\n\r\n',ME.message);
        fprintf( 'ERRROR Shot %02d_%02d_%02d after %05.1f sec\n',row,col,site,elapsedTime);
        fprintf('%s\n',ME.message);
    end
    fclose(logFileID);
    fclose(errorFileID);
end
end

%% PROCESSING FUNCTION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [IFdata] = processImage(row, col, liveSite,  fixedSite,live, settings, logFileID, errorFileID)

%%% Print status to log
siteTime = tic;
fprintf(logFileID, '%1$s : Matching %2$02d_%3$02d_%4$02d fixed to %2$02d_%3$02d_%5$02d ...\r\n', ...
    datestr(now,'HH:MM:SS'),row,col,fixedSite,liveSite);

%% LOAD AND SEGMENT %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Initialization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Set paths
shotFixed=[num2str(row),'_',num2str(col),'_',num2str(fixedSite)];

%%% Set channnels
names = settings.signals;
nucname = names{1}{1};
numParams = 8 + 2*length([settings.signals{:}]) + sum([settings.localbg{:}])+ sum([settings.ringcalc{:}]);

%%% Set segmentation parameters
nucr = settings.nucr;
debrisarea = settings.debrisarea;
boulderarea = settings.boulderarea;
blobthreshold = settings.blobthreshold;
solidity = settings.soliditythresh;

%% Load auxilliary files %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Load bgcmos
load([settings.bgcmospath],'cmosoffset');
bgcmos = cmosoffset;
[height,width]=size(bgcmos);

%%% Load bias
for i = 1:length(names)
    for j = 1:length(names{i})
        if settings.biasall{i}(j)
            biasdir = [settings.IF_imagesessions{i} 'Bias_all\'];
        else
            biasdir = [settings.IF_imagesessions{i} 'Bias\'];
        end
        if settings.bias{i}(j)
            load([biasdir,names{i}{j},num2str(fixedSite),'.mat']);
            bias_cell{i}{j} = bias;
        end
    end
end

%% Load images and segment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i = 1:length(names)
    rawFixedDir = [settings.IF_imagesessions{i},'Raw\',shotFixed,'\',shotFixed,'_'];
    %%% Load data
    for j = 1:length(names{i})
        raw{i}{j} = single(imread([rawFixedDir,names{i}{j},num2str(1),'.tif']));
        if settings.bgcmoscorrection
            raw{i}{j} = (raw{i}{j}-bgcmos);
            raw{i}{j}(raw{i}{j}<1) = 1;
        end
        if settings.bias{i}(j)
            raw{i}{j} = raw{i}{j}./bias_cell{i}{j};
        end
        if settings.postbin(i) > 0
            raw{i}{j} = imresize(raw{i}{j},settings.postbin(i));
            [height,width]=size(raw{i}{j});
        end
    end
    
    %% Segment nuclei %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    blurradius = settings.blurradius;
    switch settings.segmethod{i}
        case 'log'
            nuc_mask{i} = blobdetector_4(log(raw{i}{1}),nucr,blobthreshold,debrisarea);
        case 'thresh'
            nuc_mask{i} = threshmask(raw{i}{1},blurradius);
        case 'single'
            nuc_mask{i} = threshmask(raw{i}{1},blurradius);
            nuc_mask{i} = markershed_filter(nuc_mask{i},round(nucr*2/3),4);
        case 'double'
            nuc_mask{i} = threshmask(raw{i}{1},blurradius);
            nuc_mask{i} = markershed_filter(nuc_mask{i},round(nucr*2/3),4);
            nuc_mask{i} = secondthresh(raw{i}{1},blurradius,nuc_mask{i},boulderarea*2);
        case 'double marker'
            nuc_mask{i} = threshmask(raw{i}{1},blurradius);
            nuc_mask{i} = secondthresh_all(raw{i}{1},blurradius,nuc_mask{i});
            nuc_mask{i} = markershed_filter(nuc_mask{i},round(nucr*.4),4);
        case 'multithresh'
            nuc_mask{i} = threshmask_multi(raw{i}{1},blurradius,3, 1e-02);
            nuc_mask{i} = markershed_filter(nuc_mask{i},round(nucr*.4),4);
            %nuc_mask{i} = secondthresh(raw{i}{1},blurradius,nuc_mask{i},boulderarea);
        case 'concavity'
            imblur = imfilter(raw{i}{1},fspecial('gaussian',blurradius),'symmetric');
            nuc_mask{i} = ThreshImage(imblur);
            nuc_mask{i} = logical(imfill(nuc_mask{i},'holes'));
    end
    nuc_mask{i} = bwareaopen(nuc_mask{i},debrisarea);
    nuc_mask{i} = imclearborder(nuc_mask{i});
    
    %%% Split and filter out nuclei only for primary mask
    if i==1
        whole_mask = nuc_mask{i};
        nuc_mask{i} = segmentdeflections_bwboundaries(nuc_mask{i},nucr,debrisarea);
        nuc_mask{i} = excludelargeandwarped_3(nuc_mask{i},boulderarea,solidity);
    end
    
    %% Check for bad frame %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    IF_foreground = sum(nuc_mask{i}(:))/length(nuc_mask{i}(:));
    live_foreground = sum(live.nuc_mask_prev(:))/length(live.nuc_mask_prev(:));
    if  IF_foreground/live_foreground < settings.badFrameCheck
        IFdata = NaN * ones(live.totalcells,numParams);
        
        %% output to log
        fprintf(logFileID, '%1$s : ERROR matching %2$02d_%3$02d_%4$02d fixed to %2$02d_%3$02d_%5$02d. Too many lost cells\r\n\r\n', ...
            datestr(now,'HH:MM:SS'),row,col,fixedSite,liveSite);
        fprintf(errorFileID, '%1$s : ERROR matching %2$02d_%3$02d_%4$02d fixed to %2$02d_%3$02d_%5$02d. Too many lost cells\r\n\r\n', ...
            datestr(now,'HH:MM:SS'),row,col,fixedSite,liveSite);
        return;
    end
end

%% Check  segmentation %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if settings.debug_mode
    keyboard;
end
%{
%%% Check nuclear mask
channeltemp = 1;
extractmask = bwmorph(nuc_mask{channeltemp},'remove');
tempframe = imadjust(mat2gray(raw{channeltemp}{1}));
tempframe(:,:,2) = extractmask;
tempframe(:,:,3) = 0;
figure,imshow(tempframe);
%}
%% Align images %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Calculate jitter between IF rounds
regheight = 1:0.5*height;
regwidth = 1:0.5*width;
jitmatx = [];
jitmaty = [];

if length(names) > 1
    for i = 1:length(names)
        [reljitx,reljity] = registerimages(nuc_mask{1}(regheight,regwidth),nuc_mask{i}(regheight,regwidth));
        jitmatx = [jitmatx; reljitx];
        jitmaty = [jitmaty; reljity];
    end
else
    jitmatx = [jitmatx 0];
    jitmaty = [jitmaty 0];
end

%%% Align and crop IF rounds
cropcoors = getcropcoors([height width], jitmatx, jitmaty);
for i = 1:length(names)
    for j = 1:length(names{i})
        raw{i}{j} = raw{i}{j}(cropcoors(i+1,1):cropcoors(i+1,2),cropcoors(i+1,3):cropcoors(i+1,4));
        if settings.signal_foreground{i}(j)
            foreground_aligned{i}{j} = threshmask_adapt(raw{i}{j},blurradius);
            if sum(foreground_aligned{i}{j}(:))/length(foreground_aligned{i}{j}(:)) > .9 % account for large foregrounds
                foreground_aligned{i}{j} = zeros(height, width);
            end
        end
    end
    nuc_mask_aligned = nuc_mask{1}(cropcoors(1,1):cropcoors(1,2),cropcoors(1,3):cropcoors(1,4));
    whole_mask_aligned = whole_mask(cropcoors(1,1):cropcoors(1,2),cropcoors(1,3):cropcoors(1,4));
end

%% Subtract background %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
compression = settings.compression;
for i=1:length(names)
    for j = 1:length(names{i})
        %%% Set foreground mask
        if settings.signal_foreground{i}(j)
            mask_total  =  whole_mask_aligned | foreground_aligned{i}{j};
            nanmask_aligned{i}{j}  = imdilate(mask_total,strel('disk',nucr));
            nanmaskcyto_aligned{i}{j} = imdilate(mask_total,strel('disk',nucr*2));
        else
            nanmask_aligned{i}{j}  = imdilate(whole_mask_aligned,strel('disk',nucr));
            nanmaskcyto_aligned{i}{j} = imdilate(whole_mask_aligned,strel('disk',nucr*2));
        end
        
        %%% Blur signal
        if settings.sigblur{i}(j) > 0
            blur = imfilter(raw{i}{j},fspecial('disk',settings.sigblur{i}(j)),'symmetric');
        else
            blur  =  raw{i}{j};
        end
        
        switch settings.bgsubmethod{i}{j}
            case 'global nuclear'
                real{i}{j} = bgsubmasked_global_NR(blur,nanmask_aligned{i}{j},1,compression,settings.bgperctile);
                if settings.punctacalc{i}(j)
                    unblurred{i}{j} = bgsubmasked_global_NR(raw{i}{j},nanmask_aligned{i}{j},1,compression,settings.bgperctile);
                end
            case 'global cyto'
                real{i}{j} = bgsubmasked_global_2(blur,nanmaskcyto_aligned{i}{j},1,compression,settings.bgperctile);
                if settings.punctacalc{i}(j)
                    unblurred{i}{j} = bgsubmasked_global_2(raw{i}{j},nanmaskcyto_aligned{i}{j},1,compression,settings.bgperctile);
                end
            case 'tophat'
                real{i}{j} = imtophat(blur,strel('disk',nucr,0));
                if settings.punctacalc{i}(j)
                    unblurred{i}{j} = imtophat(raw{i}{j},strel('disk',nucr,0));
                end            
            case 'semi-local nuclear'
                real{i}{j} = bgsubmasked_global_2(blur,nanmask_aligned{i}{j},11,compression,settings.bgperctile);
                if settings.punctacalc{i}(j)
                    unblurred{i}{j} = bgsubmasked_global_2(raw{i}{j},nanmask_aligned{i}{j},11,compression,settings.bgperctile);
                end
            case 'none'
                real{i}{j} = blur;
                if settings.punctacalc{i}(j)
                    unblurred{i}{j} = raw{i}{j};
                end
        end
    end
    %%% correct IF for bleedthrough
    for j = 1:length(names{i})
        if settings.bleedthrough{i}(j)
            load([settings.bleedthroughpth{i}{j}],'bleedthroughrate');
            realbleedthrough = real{i}{j+1}*bleedthroughrate(2);
            real{i}{j} = real{i}{j}-realbleedthrough;
        end
    end
end

%% Check alignment segmentation %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if settings.debug_mode & length(names) > 1
    keyboard;
end
%{
%%% Check nuclear mask with primary nuclear channel
extractmask = bwmorph(nuc_mask_aligned,'remove');
tempframe = imadjust(mat2gray(raw{1}{1}));
tempframe(:,:,2) = extractmask;
tempframe(:,:,3) = 0;
figure,imshow(tempframe);

%%% Check nuclear areas
nuc_info = struct2cell(regionprops(nuc_mask_aligned,'Area')');
nuc_area = squeeze(cell2mat(nuc_info(1,1,:)));
hist(nuc_area,100);

%%% Check masks of each session
for session = 1:length(names)
    extractmask = bwmorph(nuc_mask_aligned,'remove');
    tempframe = imadjust(mat2gray(raw{session}{1}));
    tempframe(:,:,2) = extractmask;
    tempframe(:,:,3) = 0;
    figure,imshow(tempframe);
end

%%% Overlay nuclear images
tempframe=imadjust(mat2gray(real{1}{1}));
tempframe(:,:,2)=imadjust(mat2gray(real{2}{1}));
tempframe(:,:,3)=0;
figure,imshow(tempframe)
%}

%% Save cropped/corrected images %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~isempty(settings.crop_save) & ~settings.debug_mode
    for i = 1:length(names)
        for j = 1:length(names{i})
            save_dir = [settings.crop_save,shotFixed,'\'];
            if ~exist(save_dir)
                mkdir(save_dir)
            end
            save_name = [save_dir shotFixed,'_' names{i}{j} '_round' num2str(i) '.tif'];
            imwrite(uint16(real{i}{j}/4), save_name);
        end
    end
    %%% Save mask
    extractmask = bwmorph(nuc_mask_aligned,'remove');
    save_name = [save_dir shotFixed,'_' 'mask' '.tif'];
    imwrite(uint16(extractmask),save_name);
end

%% MATCH LIVE AND FIXED %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Pad IF images %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[cropheight,cropwidth] = size(real{1}{1});
tophalf = floor((live.prevheight*settings.scaleLive-cropheight)/2);
if mod(cropheight,2) == 1
    bottomhalf = tophalf+1;
else
    bottomhalf = tophalf;
end
lefthalf = floor((live.prevwidth*settings.scaleLive-cropwidth)/2);
if mod(cropwidth,2) == 1
    righthalf = lefthalf + 1;
else
    righthalf = lefthalf;
end

%%% Pad masks and images
nuc_mask_padded = padarray(nuc_mask_aligned,[tophalf lefthalf],'pre');
nuc_mask_padded = padarray(nuc_mask_padded,[bottomhalf righthalf],'post');
for i=1:length(names)
    for j = 1:length(names{i})
        real_padded{i}{j} = padarray(real{i}{j},[tophalf lefthalf],'pre');
        real_padded{i}{j} = padarray( real_padded{i}{j},[bottomhalf righthalf],'post');
        nanmask_padded{i}{j} = padarray(nanmask_aligned{i}{j},[tophalf lefthalf],'pre');
        nanmask_padded{i}{j} = padarray( nanmask_padded{i}{j},[bottomhalf righthalf],'post');
    end
end

%% Align live and fixed iamges %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Extract IF cell features to match to live data
nuc_label = bwlabel(nuc_mask_padded);
nuc_info = struct2cell(regionprops(nuc_mask_padded,real_padded{1}{1},'Area','Centroid','MeanIntensity')');
nuc_area = squeeze(cell2mat(nuc_info(1,1,:)));
nuc_center = squeeze(cell2mat(nuc_info(2,1,:)))';
nuc_density = squeeze(cell2mat(nuc_info(3,1,:)));
nuc_mass = nuc_density.*nuc_area;

%%% Calculate jitter between IF and live
[newheight, newwidth] = size(nuc_mask_padded);
newheight = newheight/settings.scaleLive;
newwidth = newwidth/settings.scaleLive;
if settings.match10x20x
    regheight = 1:1*newheight;
    regwidth = 1:1*newwidth;
else
    regheight = 1:.5*newheight;
    regwidth = 1:.5*newwidth;
end

if settings.scaleLive ~= 1
    reg_nuc_mask_padded = imresize(nuc_mask_padded,1/settings.scaleLive);
else
    reg_nuc_mask_padded=nuc_mask_padded;
end

[reljitx, reljity] = registerimages(live.nuc_mask_prev(regheight,regwidth),reg_nuc_mask_padded(regheight,regwidth));
reljitx = reljitx *settings.scaleLive;
reljity = reljity *settings.scaleLive;
[padheight, padwidth] = size(nuc_mask_padded);
jitcoors = getcropcoors([padheight,padwidth],reljitx,reljity);

%%% Align IF masks and images to live coordinates
reljitter = [reljitx, reljity];
prevjitter = live.jitters(live.totalframes,:)*settings.scaleLive;
IFjitter = prevjitter + reljitter;
nuc_center(:,1) = nuc_center(:,1) + IFjitter(1);
nuc_center(:,2) = nuc_center(:,2) + IFjitter(2);

%% Match live and fixed cells and correct labeling %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
initdata = [nuc_center(:,1), nuc_center(:,2), nuc_area, nuc_mass];
debugpackage = {live.rawprev, live.nuc_mask_prev, nuc_mask_padded, prevjitter, reljitter};
livetrack = squeeze(live.tracedata(:,live.totalframes,1:4));
livetrack(:,1:2) = livetrack(:,1:2)*settings.scaleLive;
livetrack(:,3:4) = livetrack(:,3:4)*settings.scaleLive^2;

[tracked,nuc_label_track] = adaptivetrack_IF_1(livetrack, initdata, nuc_label, nucr,...
    settings.distthresh, settings.arealowthresh, settings.areahighthresh, debugpackage);

%%% Calculate number lost cells and record in log file
if settings.match10x20x
    approx_perc_lost_cells = 100*(sum(~isnan(live.tracedata(:,live.totalframes,1)))/4 - sum(~isnan(tracked(:,1))))/...
        sum(~isnan(live.tracedata(:,live.totalframes,1)));
    fprintf(logFileID, '%1$s : Lost ~%2$4.1f perc of cells\r\n', ...
        datestr(now,'HH:MM:SS'),approx_perc_lost_cells);
    if approx_perc_lost_cells > 10
        fprintf(errorFileID, '%1$s : WARNING matching %2$02d_%3$02d_%4$02d fixed to %2$02d_%3$02d_%5$02d Lost ~%6$4.1f perc of cells\r\n', ...
            datestr(now,'HH:MM:SS'),row,col,fixedSite,liveSite, approx_perc_lost_cells);
    end
else
    approx_perc_lost_cells = 100*(sum(~isnan(live.tracedata(:,live.totalframes,1))) - sum(~isnan(tracked(:,1))))/...
        sum(~isnan(live.tracedata(:,live.totalframes,1)));
    fprintf(logFileID, '%1$s : Lost %2$4.1f perc of cells\r\n', ...
        datestr(now,'HH:MM:SS'),approx_perc_lost_cells);
    if approx_perc_lost_cells > 10
        fprintf(errorFileID, '%1$s : WARNING matching %2$02d_%3$02d_%4$02d fixed to %2$02d_%3$02d_%5$02d Lost %6$4.1f perc of cells\r\n', ...
            datestr(now,'HH:MM:SS'),row,col,fixedSite,liveSite,approx_perc_lost_cells);
    end
end
tracked_cells = length(unique(nuc_label));
nuc_label_track_jit = nuc_label_track(jitcoors(2,1):jitcoors(2,2),jitcoors(2,3):jitcoors(2,4));

%% Check tracking quality %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if settings.debug_mode
    keyboard;
end
%{

prev_mask_jit = imresize(live.nuc_mask_prev,settings.scaleLive);
prev_mask_jit = prev_mask_jit(jitcoors(1,1):jitcoors(1,2),jitcoors(1,3):jitcoors(1,4));
nuc_mask_jit = nuc_mask_padded(jitcoors(2,1):jitcoors(2,2),jitcoors(2,3):jitcoors(2,4));
for i=1:length(names)
    for j = 1:length(names{i})
        real_padded_jit{i}{j} = real_padded{i}{j}(jitcoors(2,1):jitcoors(2,2),jitcoors(2,3):jitcoors(2,4));
    end
end

%Check jitter
extractmask=bwmorph(nuc_mask_jit,'remove');
[tempheight,tempwidth]=size(extractmask);
tempframe=zeros(tempheight,tempwidth,3);
tempframe(:,:,1)=prev_mask_jit;
tempframe(:,:,2)=nuc_mask_jit;
figure,imshow(tempframe);
hold on

%Check tracking
extractmask1=bwmorph(nuc_mask_jit,'remove');
extractmask2=bwmorph(nuc_label_track_jit,'remove');
[tempheight,tempwidth]=size(extractmask1);
tempframe=zeros(tempheight,tempwidth,3);
tempframe(:,:,1)=extractmask1;
tempframe(:,:,2)=extractmask2;
tempframe(:,:,3)=imadjust(mat2gray(real_padded_jit{1}{1}));
figure,imshow(tempframe);

extractmask=bwmorph(nuc_mask_padded,'remove');
[tempheight,tempwidth]=size(extractmask);
tempframe=zeros(tempheight,tempwidth,3);
tempframe(:,:,1)=imadjust(mat2gray(real_padded{1}{1}));
tempframe(:,:,2)=extractmask;
%tempframe(:,:,3)=marker_mask;
figure,imshow(tempframe);
hold on
scatter(livetrack(:,1)-IFjitter(1),livetrack(:,2)-IFjitter(2),'w')

figure, imshow(live.rawprev,[]);
hold on
scatter((live.tracedata(:,live.totalframes,1)-prevjitter(1))*2,(live.tracedata(:,live.totalframes,2)-prevjitter(2))*2,'w')

%%% overlay nuclear images %%%%%%%%%%%%%%%%%
[rawprevcrop,raw1crop]=cropboth(imresize(live.rawprev,settings.scaleLive),real_padded{1}{1},reljitx,reljity);
tempframe=imadjust(mat2gray(rawprevcrop));
tempframe(:,:,2)=imadjust(mat2gray(raw1crop));
tempframe(:,:,3)=0;
figure,imshow(tempframe)

%}

%% MEASSURE FEATURES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
numcells = numel(tracked(:,1));
nuc_center = tracked(:,[1 2]);
nuc_area = tracked(:,3);
nuc_mass = tracked(:,4);
cellid = find(~isnan(tracked(:,1)));
numlivecells = numel(cellid);
nuc_info = regionprops(nuc_label_track, 'PixelIdxList', 'Area', 'Centroid');

%% Initialize storage variables %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
nanvec = ones(numcells,1)*NaN;
sigringmedian{1} = [];
localbg{1} = [];
IF_position  = [nanvec nanvec];
for i = 1:length(names)
    for j = 1:length(names{i})
        sigmean{i}{j} = nanvec;
        sigmedian{i}{j} = nanvec;
        if settings.ringcalc{i}(j)
            sigringmedian{i}{j} = nanvec;
        end
        if settings.localbg{i}(j)
            localbg{i}{j} = nanvec;
        end
    end
end
if any(cell2mat(settings.ringcalc))
    if (settings.magnification == 10 & settings.binsize == 1) | ...
            (settings.magnification == 20 & (settings.binsize == 2 | settings.postbin))
        innerrad = 1; outerrad = 5;
    else
        innerrad = 2; outerrad = 10;
    end
    ring_label = getcytoring_thicken(nuc_label,innerrad,outerrad,real{1}{1});
    ring_info = regionprops(ring_label,'PixelIdxList');
    %%% Check cytoring
    if settings.debug_mode
        keyboard;
    end
    %{
            %%% debugging: view images %%%%%%%%%%
            temp_ring  =  ring_label > 0;
            extractmask = bwmorph(temp_ring,'remove');
            signal  =  real_padded{1}{1};
            intensities  =  signal.*temp_ring;
            [height,width] = size(signal);
            tempframe = zeros(height,width,3);
            tempframe(:,:,1) = imadjust(mat2gray(signal));
            tempframe(:,:,2) = extractmask;;
            %tempframe(:,:,3) = marker_mask;
            figure,imshow(tempframe);
    %}
end

%% Measure cell features%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i = 1:length(names)
    for j = 1:length(names{i})
        real_temp = real_padded{i}{j};
        real_temp_masked = real_temp;
        real_temp_masked(nanmask_padded{i}{j}) = NaN;
        for n = 1:numlivecells
            cc=cellid(n);
            sigmean{i}{j}(cc) = mean(real_temp(nuc_info(cc).PixelIdxList));
            sigmedian{i}{j}(cc) = median(real_temp(nuc_info(cc).PixelIdxList));
            IF_position(cc,:) = nuc_info(cc).Centroid - [tophalf lefthalf];
            if settings.localbg{i}(j)
                localbg{i}{j}(cc) = getlocalbg(real_temp_masked, nuc_info(cc).Centroid,100, 50,.15);
            end
            if settings.ringcalc{i}(j)
                if cc<numel(ring_info)
                    ringall = real_temp(ring_info(cc).PixelIdxList);
                    ringall(ringall>prctile(ringall,98)) = [];
                    ringforeground = ringall(ringall>settings.ringthresh{i}(j));
                    if numel(ringforeground)<settings.minringsize
                        ringforeground = ringall;
                    end
                    if numel(ringall)>100
                        sigringmedian{i}{j}(cc) = nanmedian(ringforeground);
                    end
                end
            end
        end
    end
end

%%% Compile data
IFdata = [IF_position(:,1),IF_position(:,2),nuc_area,repmat(IFjitter,size(IF_position,1),1),...
    repmat(row,size(IF_position(:,1),1),1),...
    repmat(col,size(IF_position(:,1),1),1),...
    repmat(fixedSite,size(IF_position(:,1),1),1),...
    cell2mat([sigmean{:}]),cell2mat([sigmedian{:}]),cell2mat([localbg{:}]),...
    cell2mat([sigringmedian{:}])];

%%% Output to log file
elapsedSiteTime = toc(siteTime);
fprintf(logFileID, '%1$s : Finished successfully, %2$05.1f sec elapsed\r\n', ...
    datestr(now,'HH:MM:SS'),elapsedSiteTime);
end


function [upperleft,upperright,lowerleft,lowerright]=siteChange(numsites,site)
if numsites==4
    switch site
        case 1
            upperleft=1;
            upperright=2;
            lowerleft=5;
            lowerright=6;
        case 2
            upperleft=3;
            upperright=4;
            lowerleft=7;
            lowerright=8;
        case 3
            upperleft=9;
            upperright=10;
            lowerleft=13;
            lowerright=14;
        case 4
            upperleft=11;
            upperright=12;
            lowerleft=15;
            lowerright=16;
    end
end
end

function updateddata=addGoodRows(orgdata,newdata)
goodrows=~isnan(newdata(:,1));
updateddata=orgdata;
updateddata(goodrows,:)=newdata(goodrows,:);
end