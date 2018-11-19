%% INPUT %%
% get the file directory
uiwait(msgbox('Load cell movie folder'));
dpath = uigetdir('');

% ask the user for an ouput stamp
prompt = {'Provide a name for the output files', 'Movie ID (n) if file format is cb_(n)_m.tif'};
title = 'Parameters';
dims = [1 35]; % set input box size
user_answer = inputdlg(prompt,title,dims); % get user answer
output_name = (user_answer{1,1});
cell_ID = str2double(user_answer{2,1});

% load streamline end points
stream = load (fullfile ([dpath '/data'], ['flow_streamlines_endpts_', output_name, '.mat']));
stream = stream.stream_end_pts;

% get number of frames of the movie
nt = length(stream);

%% PERCENTAGE of STREAMLINES at the primary sink %%

f_percent = zeros(nt,3);
for k = 1:nt
    
    % find max 3 sinks by sorting frequency field
    stream_f = stream(k).f(:);
    [stream_f_sorted, stream_f_sorted_index] = sort(stream_f, 'descend');
    
    % highest frequency of streamlines at an end point
    f1 = stream_f_sorted(1,1);
    f2 = stream_f_sorted(2,1);
    f3 = stream_f_sorted(3,1);
    
    % sum of all streamlines at all end points
    f_sum = sum(stream(k).f(:));
    
    f_percent(k,1) = f1/f_sum * 100;
    f_percent(k,2) = f2/f_sum * 100;
    f_percent(k,3) = f3/f_sum * 100;
    
end

average_f_percent = mean(f_percent);

%% SAVE %%

% save [f_percent]: percentage of streamlines at the primary sink for each frame [-]
save(fullfile([dpath '/data'], ...
        ['streamlines_percentage_sinks_', output_name, '.mat']), ...
        'f_percent');

% save [flow_speed_average]: percentage of streamlines at the primary sink averaged for all frames [-]
save(fullfile([dpath '/data'], ...
        ['streamlines_percentage_sinks_average_', output_name, '.mat']), ...
        'average_f_percent');

clear; close all