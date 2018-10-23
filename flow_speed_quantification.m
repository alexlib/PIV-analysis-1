%% flow_speed_quantification.m %%

% Take as input the directory containing the cell movie and PIV results

% Return the average flow speed for each frame and the average flow speed
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

% initialis output vector
flow_speed = zeros(nt-1, 1);

%% FLOW SPEED %%

for jj = 1:nt-1
    
    % load current and next frame
    currentFrame = double(imread(fullfile(d, sprintf ...
        ('cb%d_m.tif', cell_ID)),jj)) / 255;
    
    nextFrame = double(imread(fullfile(d, sprintf ...
        ('cb%d_m.tif', cell_ID)),jj+1)) / 255;
    
    % find intersection
    cellOutline1 = detectObjectBw(currentFrame, dilationSize, erosionSize, connectivityFill);
    cellOutline2 = detectObjectBw(nextFrame, dilationSize, erosionSize, connectivityFill);
    cellOutline = cellOutline1 .* cellOutline2;
    
    % calculate field magnitude (velocity: [um/min])
    magnitude = hypot(flow(jj).vx, flow(jj).vy);
    
    % apply mask
    magnitude = magnitude .* cellOutline;
    
    file_name = [d, '/', sprintf('no_cb%d_m.tif', cell_ID)];
    if exist(file_name, 'file') == 2
        
        no_cb_frame = double(imread(fullfile(file_name),jj)) / 255;
        lim = logical(no_cb_frame);
        
        magnitude = magnitude .* lim;   % remove cell body if no_cb exists
    end

    % if outside cell region make NaN
    magnitude(cellOutline == 0) = NaN;      
    
    % save mean flow velocity [um/min]
    flow_speed(jj,1) = nanmean(magnitude, 'all');
    
end

% average across all frames [um/min]
flow_speed_average = mean(flow_speed);

%% SAVE %%

% save [flow_speed]: mean flow velocity for each frame [um/min]
save(fullfile([d '/data'], ...
        ['flow_speed_', output_name, '.mat']), ...
        'flow_speed');

% save [flow_speed_average]: mean flow velocity averaged for all frames [um/min]
save(fullfile([d '/data'], ...
        ['flow_speed_average_', output_name, '.mat']), ...
        'flow_speed_average');

clear; close all