%% divergence_quantification.m %%

% Take as input the directory containing the cell movie and PIV results

% Return the average divergence for each frame and the average divergence
% across all frames and save them in the folder [data]

% If the .tif stack with the cell body removed is available in the folder,
% the cell body information is excluded from the output computation

%% INPUT %%

% get the file directory
uiwait(msgbox('Load cell movie folder'));
d = uigetdir('');
warning off

% ask the user for an ouput stamp
prompt = {'Provide a name for the output files', 'Movie ID (n) if file format is cb_(n)_m.tif'};
title = 'Parameters';
dims = [1 35]; % set input box size
user_answer = inputdlg(prompt,title,dims); % get user answer
output_name = (user_answer{1,1});
cell_ID = str2double(user_answer{2,1});

% parameters
dilationSize = 4;
erosionSize = 12;
connectivityFill = 4;

% load interpolated filed
flow = load (fullfile ([d '/data'], ['piv_field_interpolated_', output_name, '.mat']));
flow = flow.vfilt;

nt = length(flow);

% initialise output vector
diverg = zeros(nt-1, 1);

%% DIVERGENCE %%

for jj = 1:nt-1
    
    % load current and next frame
    currentFrame = double(imread(fullfile(d, sprintf ...
        ('cb%d_m.tif', cell_ID)),jj)) / 255;
    
    nextFrame = double(imread(fullfile(d, sprintf ...
        ('cb%d_m.tif', cell_ID)),jj+1)) / 255;
    
    % calculate divergence
    u = flow(jj).vx;
    v = flow(jj).vy;

    div = divergence(u,v);
    
    % find intersection
    cellOutline1 = detectObjectBw(currentFrame, dilationSize, erosionSize, connectivityFill);
    cellOutline2 = detectObjectBw(nextFrame, dilationSize, erosionSize, connectivityFill);
    cellOutline = cellOutline1 .* cellOutline2;
    cellOutline(cellOutline==0)=NaN;
    
    div_mask = div .* cellOutline;
    
    % remove cell body if present
    file_name = [d, '/', sprintf('no_cb%d_m.tif', cell_ID)];
    if exist(file_name, 'file') == 2
        
        no_cb_frame = double(imread(fullfile(file_name),jj)) / 255;
        lim = logical(no_cb_frame);
        
        div_mask = div_mask .* lim;   % remove cell body if no_cb exists
        div_mask(lim == 0) = NaN;
    end
    
    % save mean divergence [A.U.]
    diverg(jj,1) = nanmean(div_mask, 'all');
    
end

% average across all frames [A.U.]
diverg_average = mean(diverg);

%% SAVE %%

% save [diverg]: mean divergence for each frame [A.U.]
save(fullfile([d '/data'], ...
        ['divergence_', output_name, '.mat']), ...
        'diverg');

% save [diverg_average]: mean divergence averaged for all frames [A.U.]
save(fullfile([d '/data'], ...
        ['divergence_average_', output_name, '.mat']), ...
        'diverg_average');

clear; close all