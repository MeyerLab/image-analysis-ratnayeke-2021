cd('F:\Data\C-Cdt1\C204-live\Processing')
%% Rename live sequence
% IX_Micro_rename({'J:\8TB4\IXM_raw\2019102219-C204-live\2019-10-22\10917'},...
%      'J:\8TB4\Data\IXM\C204-live\Raw',{'CFP','YFP','RFP'},'COPY',false)
%  %%
% IX_Micro_rename({'J:\8TB4\IXM_raw\2019102219-C204-IF1\2019-10-23\10918'},...
%      'J:\8TB4\Data\IXM\C204-IF1\Raw',{'DAPI','YFP','FarRed'},'COPY',false)
% IX_Micro_rename({'J:\8TB4\IXM_raw\2019102219-C204-IF2\2019-10-24\10921'},...
%      'J:\8TB4\Data\IXM\C204-IF2\Raw',{'DAPI','YFP','FarRed'},'COPY',false)

 %% Calculate Bias live
clear p
p.biaspath='J:\8TB4\Data\IXM\C204-live\Bias';  % Output path for bias
p.imagepath='J:\8TB4\Data\IXM\C204-live\Raw';  % Image directory. If nikon, single folder for all sites
p.shadingpath='C:\Users\nalin\Documents\GitHub\cell-cycle-tracking\BGimages\IX_Liu\cmosoffset_bin1.mat'; % cmos offset file for IX micro
p.names={
    'CFP';
    'YFP';
    'RFP';
    };
p.row_mat = [2:7];
p.col_mat = [2:11];
p.site_mat = [1:6];
p.frame_mat=[2 30];
p.biasAll = 1; % Save averaged bias across sites
% Formatting code for nikon files, 1$ is timepoint, 2$ is well, 3$ is point
% 'Time%1$05d_Well%2$s_Point%2$s_%3$04d_*.tiff' if multipoint
p.formatCode = 'Time%1$05d_Well%2$s_Point%2$s_%3$04d_*.tiff';
p.microscope = 'IXM';
p.nuc_channel = 1;

%%% Settings
p.maskforeground = 1;   % 1 to mask nuclei
p.nucradius=12;%12;
p.blur_radius = 5;
p.adaptive = [0 0 0 0];   % use add channels together to segment foreground
p.dilate = {.75,2,.75 .75};   % multiples of nucradius, default .5, to expand mask
p.foreground_calc = 0;  % 1 for foreground calc (average foreground signal)
p.method = 'block';     % or pixel
p.blocknum= 11;
p.prctilethresh = 50;
p.compress = .25;
p.prctile_thresh=[0 100]; % pixel remove outliers
p.sigma = 25;             % pixel smooth window


biasCalc(p,0);


%% Prep live processing 
%% Paths
s.experiment_name='C204-live';                % Experiment name
s.image_drive = 'J:\8TB4\Data\IXM\C204-live\';    % Location of images base folder
s.savepath=fullfile('F:\Data\C-Cdt1\',s.experiment_name,'Data'); % Output location of mat files
s.imagepath=fullfile(s.image_drive,'Raw');                       % All sites in same folder for nikon
s.biaspath=fullfile(s.image_drive,'Bias_all');                       % Location of bias files
s.maskpath=fullfile(s.image_drive,'Mask');                       % Future location of mask saving
s.bgcmospath='C:\Users\nalin\Documents\GitHub\cell-cycle-tracking\BGimages\IX_Liu\cmosoffset_bin1.mat';
% Formatting code for nikon files, 1$ is timepoint, 2$ is well, 3$ is point
s.formatCode = 'Time%1$05d_Well%2$s_Point%2$s_%3$04d_*.tiff'; %'Time%1$05d_Well%2$s_Point%2$s_%3$04d_*.tiff' if multipoint
s.microscope = 'IXM';
s.nucChannel = 1;

%%% General parameters
s.startFrame = 1; 
% s.endFrame = getMaxFrame(fullfile(s.imagepath,'2_2_1'),'Time(\d+)_');
s.endFrame = 33;
s.magnification=10;               % 10=10x or 20=20x
s.binsize=1;                      % 1=bin 1 or 2=bin 2
s.postbin = 0;             % 0 for no software bin, number for scaling factor (e.g. 0.5 for 2x2 bin);
s.signals={'CFP','YFP','RFP'};
s.maskwrite = 1;                  % 1 = save an image with the nucmask; 0 = dont save an image with the nucmask
s.maskname = 'nucedge_';
s.register = 1;                   % Register images between timepoints for all
s.register_exception = [];        % If don't register images, manually put in sites to register

%%% Quantification parameters
s.bgcmoscorrection = 1;
s.bias = [1 1 1 ];
s.signal_foreground = [0 0 0 ];
s.bgsubmethod = {'global nuclear','global cyto','global nuclear'}; 
                                  % Options:'global nuclear','global cyto','tophat','semi-local nuclear', 'none'
s.compression = 4;                % For bg subtraction
s.bgprctile = [25 25 25 ];         % Set bg as perctile for each channel
s.sigblur = [3 3 3 ]; 
s.localbgmeasure = [0 0 0 ];       % Measure local background in box around cell
s.ringcalc = [0 1 0 ];
s.ringthresh = [0 0 0];         % Threshold for foreground ring pixels
s.punctacalc = 0;                 % Analyze puncta in nucleus
s.punctaThresh = [];
s.varThresh = [];

%%% Segmentation parameters
s.firstsegmethod = 'log contour';  % Options: 'concavity', 'log', 'single adapt', 'double adapt', 'single', 'double', 'log contour'
s.secondsegmethod = 'log contour'; % Options: 'concavity', 'log', 'single adapt', 'double adapt', 'single', 'double','log contour'
s.nucr = 12;                     % 10x bin1 = 12 and 20x bin2 = 12
s.blurradius  =  3;              % 10x: 3
s.soliditythresh = 0.8;          % Minimum solidity of nucleus allowed
s.debrisarea = 50;              % 10x = 100 % 150 if no mitosis
s.boulderarea = 1500;            % 10x = 1500
s.blobthreshold = -0.02;         % For blobdector 'log' segmentation
s.split_mult = 1;
%%% Tracking parameters
s.maxjump = s.nucr*3;
s.masschangethreshold = 0.30;
s.areachangethreshold = 0.60;
s.daughtervariance = 0.10;

% Timelapse(s,2,2,1,0)
% % 
%% Run timelapse
rows = [2:7];
cols = [2:11];
sites = [1:6];
Parallelwell({@Timelapse},s,rows,cols,sites)


%% Calculate Bias IF1
clear p
p.biaspath='J:\8TB4\Data\IXM\C204-IF1\Bias';  % Output path for bias
p.imagepath='J:\8TB4\Data\IXM\C204-IF1\Raw';  % Image directory. If nikon, single folder for all sites
p.shadingpath='C:\Users\nalin\Documents\GitHub\cell-cycle-tracking\BGimages\IX_Liu\cmosoffset_bin1.mat'; % cmos offset file for IX micro
p.names={
    'DAPI';
    'YFP';
    'FarRed';
    };
p.row_mat = [2:4];
p.col_mat = [1];
p.site_mat = [1:24];
p.frame_mat=[1];
p.biasAll = 1; % Save averaged bias across sites
% Formatting code for nikon files, 1$ is timepoint, 2$ is well, 3$ is point
% 'Time%1$05d_Well%2$s_Point%2$s_%3$04d_*.tiff' if multipoint
p.formatCode = 'Time%1$05d_Well%2$s_Point%2$s_%3$04d_*.tiff';
p.microscope = 'IXM';
p.nuc_channel = 1;

%%% Settings
p.maskforeground = 0;   % 1 to mask nuclei
p.nucradius=12;%12;
p.blur_radius = 5;
p.adaptive = [0 0 0 0];   % use add channels together to segment foreground
p.dilate = {1,.75,.75 .75};   % multiples of nucradius, default .5, to expand mask
p.foreground_calc = 0;  % 1 for foreground calc (average foreground signal)
p.method = 'block';     % or pixel
p.blocknum= 11;
p.prctilethresh = 50;
p.compress = .25;
p.prctile_thresh=[0 100]; % pixel remove outliers
p.sigma = 25;             % pixel smooth window


biasCalc(p,0);

%%% Calculate Bias IF2
clear p
p.biaspath='J:\8TB4\Data\IXM\C204-IF2\Bias';  % Output path for bias
p.imagepath='J:\8TB4\Data\IXM\C204-IF2\Raw';  % Image directory. If nikon, single folder for all sites
p.shadingpath='C:\Users\nalin\Documents\GitHub\cell-cycle-tracking\BGimages\IX_Liu\cmosoffset_bin1.mat'; % cmos offset file for IX micro
p.names={
    'DAPI';
    'YFP';
    'FarRed';
    };
p.row_mat = [2:4];
p.col_mat = [1];
p.site_mat = [1:24];
p.frame_mat=[1];
p.biasAll = 1; % Save averaged bias across sites
% Formatting code for nikon files, 1$ is timepoint, 2$ is well, 3$ is point
% 'Time%1$05d_Well%2$s_Point%2$s_%3$04d_*.tiff' if multipoint
p.formatCode = 'Time%1$05d_Well%2$s_Point%2$s_%3$04d_*.tiff';
p.microscope = 'IXM';
p.nuc_channel = 1;

%%% Settings
p.maskforeground = 0;   % 1 to mask nuclei
p.nucradius=12;%12;
p.blur_radius = 5;
p.adaptive = [0 0 0 0];   % use add channels together to segment foreground
p.dilate = {1,.75,.75 .75};   % multiples of nucradius, default .5, to expand mask
p.foreground_calc = 0;  % 1 for foreground calc (average foreground signal)
p.method = 'block';     % or pixel
p.blocknum= 11;
p.prctilethresh = 50;
p.compress = .25;
p.prctile_thresh=[0 100]; % pixel remove outliers
p.sigma = 25;             % pixel smooth window


biasCalc(p,0);


%% Setup add IF images
clear settings
settings.data_path = 'F:\Data\C-Cdt1\C204-live\Data\';      % Output location of mat files
settings.IF_imagesessions = {'J:\8TB4\Data\IXM\C204-IF1\','J:\8TB4\Data\IXM\C204-IF2\'};    
                                                            % Cell array containing all imaging sessions to be matched
settings.live_imagepath = 'J:\8TB4\Data\IXM\C204-live\Raw\';    % Live imaging raw image path
settings.bgcmospath = 'C:\Users\nalin\Documents\GitHub\cell-cycle-tracking\BGimages\IX_Liu\cmosoffset_bin1.mat';
settings.crop_save = 'J:\8TB4\Data\IXM\C204-IFcrop\';           % Output cropped images, leave empty if no save
settings.mask_save = 'J:\8TB4\Data\IXM\C204-IFcrop\';           % Output mask, leave empty if no save
settings.maskname = 'mask';
settings.primaryMaskRound = 1;
settings.maskIndex = [1 1];

%%% General parameters
settings.microscope = 'IXM';
% Formatting code for nikon files, 1$ is timepoint, 2$ is well, 3$ is point
settings.formatCodeLive = 'Time%1$05d_Well%2$s_Point%2$s_%3$04d_*.tiff';
settings.formatCodeFixed = 'Time%1$05d_Well%2$s_Point%2$s_%3$04d_*.tiff';
settings.magnification = 20;     % 10 = 10x or 20 = 20x
settings.binsize = 1;            % 1 = bin 1 or 2 = bin 2
settings.postbin = [0 0];           % 0 for no software bin, number for scaling factor (e.g. 0.5 for 2x2 bin);
settings.match10x20x = 1;
settings.numsites = 6;           % Number of sites imaged for 20x to 10x (double check order is correct)
settings.scaleLive = 2;          % Scale live to have same pixel size as final IF image
settings.signals = {{'DAPI','YFP','FarRed'},{'DAPI','YFP','FarRed'}};  % Each imaging session in a cell inside cell array
settings.nucLive = 'CFP_';       % Label for IX micro live nucleus (assume first tiff in stack for nikon)
settings.liveChannel = 1;         % If nikon use this tiff in stack for nuclear live
settings.manualLiveFrame = [];   % Manually set last frame for live imaging, otherwise use tracedata if empty

%%% Segmentation parameters
settings.segmethod = {'concavity','thresh'};  % 'log' or 'single' or 'double'
settings.nucr = 24;                           % 10x bin1 = 12 and 20x bin2 = 12
settings.debrisarea = 400;                    % 100
settings.boulderarea = 6000;                  % 1500 
settings.blobthreshold = -0.03;               % For blobdector 'log' segmentation
settings.blurradius = 3;                      % Blur for blobdetector
settings.soliditythresh = 0.80;               % Minimum solidity of nucleus allowed
settings.badFrameCheck = .25;                 % Min fraction of cells untracked before logging error, 0 for no check
settings.split_mult = 1;

%%% Quantification parameters
settings.bias = {[1 1 1],[1 1 1]};
settings.biasall = {[0 0 0],[0 0 0]};
settings.sigblur = {[0 0 0],[0 0 0]};
settings.signal_foreground = {[0 0 0],[0 0 0]};
settings.bleedthrough = {[0 0 0],[0 0 0]};   % Calculate bleedthrough for channel
settings.bleedthroughslope = {};              % Cell array of cell arrays
settings.bleedthroughoff = {};                % Cell array of cell arrays
settings.ringcalc = {[0 1 1],[0 1 1]};
settings.ringthresh = {[0 0 0 ],[0 0 0]};    % Threshold for foreground ring pixels
settings.punctacalc = {[0 0 0],[0 0 0]};     % Analyze puncta in nucleus
settings.punctaThresh = {{[],[],[]},{}};      % Threshold for tophat filter for puncta
settings.punctatopsize = 2;                   % Top hat filter size
settings.cytopuncta = {[0 0 0],[0 0 0]};
settings.thickenradius = 2*settings.nucr; 

settings.localbg = {[0 0 0],[0 0 0]};        % Measure local background in box around cell
settings.minringsize = 100;
settings.bgcmoscorrection = 1;                % 1 = correct for shading; 0 = dont correct for shading;
settings.compression = 4;
settings.bgsubmethod = {{'global nuclear','none', 'none'},{'global nuclear','none', 'none'}}; % 'global nuclear','global cyto','tophat','semi-local nuclear'
settings.bgperctile = {[25 25 25],[25 25 25]};  % Set bg as perctile for each channel
settings.frameIF=1;
 


%%% Tracking parameters
settings.distthresh = 3*settings.nucr;
settings.arealowthresh = -.6;
settings.areahighthresh = .6;
settings.maxjit = 200;

% Timelapse_addIF( settings, 4,9,1, 1)

%% Run timelapse
rows = [2:3];
cols = [2:11];
sites = [1:6];

Parallelwell({@Timelapse_addIF},settings,rows,cols,sites)