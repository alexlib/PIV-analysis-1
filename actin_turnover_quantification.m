%% actin_turnover_quantification.m %%

% Take as input the directory containing the cell movie and PIV results

% Return the average turnover for each frame and the average turnover
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
dt = 5;
dx = 5;
dy = 5;
dilationSize = 4;
erosionSize = 12;
connectivityFill = 4;

% load interpolated filed
flow = load (fullfile ([d '/data'], ['piv_field_interpolated_', output_name, '.mat']));
flow = flow.vfilt;

nt = length(flow);

% initialis output vector
turnover = zeros(nt-1, 1);

%% FLOW SPEED %%

for jj = 1:nt-1
    
    % load current and next frame
    currentFrame = double(imread(fullfile(d, sprintf ...
        ('cb%d_m.tif', cell_ID)),jj)) / 255;
    
    nextFrame = double(imread(fullfile(d, sprintf ...
        ('cb%d_m.tif', cell_ID)),jj+1)) / 255;
    
    % compute d(intensity)/d(t)
    didt = (nextFrame - currentFrame) / dt;
    
    % find didx, didy, dudx, dvdy
    u = flow(jj).vx;
    v = flow(jj).vy;
    
    dudx = zeros(size(u));
    dvdy = zeros(size(v));
    didx = zeros(size(currentFrame));
    didy = zeros(size(currentFrame));
    
    for i = dy+1:dy:size(currentFrame, 1)-dy
        for j = dx+1:dx:size(currentFrame, 2)-dx
            dudx(i, j) = (u(i, j+dx) - u(i, j-dx)) / 2 * dx;
            dvdy(i, j) = (v(i+dy, j) - v(i-dy, j)) / 2 * dy;
            didx(i, j) = (currentFrame(i, j+dx) - currentFrame(i, j-dx)) / 2 * dx;
            didy(i, j) = (currentFrame(i+dy, j) - currentFrame(i-dy, j)) / 2 * dy;
        end
    end
    
    % compute net turnover
    net_turnover = didt + currentFrame .* (dudx + dvdy) + u .* didx + v .* didy;
        
    % interpolate net turnover to cover the full outline
    if dx ~= 1 || dy ~= 1
        [X0, Y0] = meshgrid(dx+1:dx:size(currentFrame,2)-dx, dy+1:dy:size(currentFrame, 1)-dy);
        [X, Y] = meshgrid(1:size(currentFrame,2), 1:size(currentFrame,2));
        net_turnover = net_turnover(dy+1:dy:size(currentFrame, 1)-dy, ...
            dx+1:dx:size(currentFrame, 2)-dx);
        interpolatedTurnover = interp2(X0, Y0, net_turnover, X, Y, 'cubic');
        
    end
    
    % find intersection
    cellOutline1 = detectObjectBw(currentFrame, dilationSize, erosionSize, connectivityFill);
    cellOutline2 = detectObjectBw(nextFrame, dilationSize, erosionSize, connectivityFill);
    cellOutline = cellOutline1 .* cellOutline2;
    cellOutline(cellOutline==0)=NaN;
    
    turnover_mask = interpolatedTurnover .* cellOutline;
    
    % remove cell body if present
    file_name = [d, '/', sprintf('no_cb%d_m.tif', cell_ID)];
    if exist(file_name, 'file') == 2
        
        no_cb_frame = double(imread(fullfile(file_name),jj)) / 255;
        lim = logical(no_cb_frame);
        
        turnover_mask = turnover_mask .* lim;   % remove cell body if no_cb exists
        turnover_mask(lim == 0) = NaN;
    end
    
    % save mean flow velocity [um/min]
    turnover(jj,1) = nanmean(turnover_mask, 'all');
    
end

% average across all frames [um/min]
turnover_average = mean(turnover);

%% SAVE %%

% save [flow_speed]: mean flow velocity for each frame [um/min]
save(fullfile([d '/data'], ...
        ['turnover_', output_name, '.mat']), ...
        'turnover');

% save [flow_speed_average]: mean flow velocity averaged for all frames [um/min]
save(fullfile([d '/data'], ...
        ['turnover_average_', output_name, '.mat']), ...
        'turnover_average');

clear; close all