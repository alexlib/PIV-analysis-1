%% INPUT %%
% get the file directory
uiwait(msgbox('Load cell movie folder'));
d = uigetdir('');

% ask the user for an ouput stamp
prompt = {'Provide a name for the output files', 'Movie ID (n) if file format is cb_(n)_m.tif'...
    'Pixel length [um]'};
title = 'Parameters';
dims = [1 35]; % set input box size
user_answer = inputdlg(prompt,title,dims); % get user answer
output_name = (user_answer{1,1});
cell_ID = str2double(user_answer{2,1});
px_length = str2double(user_answer{3,1});   % [um]

% parameters
dx_um = 2.5;    % [um] has to be the same as streamlines_plot.m
dy_um = 2.5;    % [um] has to be the same as streamlines_plot.m
dx = ceil(dx_um/px_length); % [px]
dy = ceil(dy_um/px_length); % [px]

% load interpolated filed
flow = load (fullfile ([d '/data'], ['piv_field_interpolated_', output_name, '.mat']));
flow = flow.vfilt;

% number of frames in the movie
nt = length(imfinfo(fullfile (d, sprintf('cb%d_m.tif', cell_ID))));

% load cell path
track = load (fullfile ([d '/data'], ['cell_track_', output_name, '.mat']));
track = track.path;

track = track/px_length;    % [px]
track_smooth = [smooth(track(:,1)), smooth(track(:,2))]; % [px] smooth track with moving average to reduce noise

track_diff = [diff(track_smooth(:,1)) diff(track_smooth(:,2))];

% load streamline end points
stream = load (fullfile ([d '/data'], ['flow_streamlines_endpts_', output_name, '.mat']));
stream = stream.stream_end_pts;

% parameters
dilationSize = 4;
erosionSize = 12;
connectivityFill = 4;
dx = 5;
dy = 5;

% initialise
[m, n] = meshgrid(1:size(flow(1).vx,2),...
    1:size(flow(1).vx,1));
grad_at_sink = zeros(nt-1,3) .* NaN;

%% %%

for j = 1:nt-1
    
    % load images
    currentFrame = double(imread(fullfile(d, sprintf('cb%d_m.tif', cell_ID)),j)) / 255;
    cellOutline = detectObjectBw(currentFrame, dilationSize, erosionSize, connectivityFill);
    
    % calculate angle flow field to direction of motion
    cosine = zeros(size(m,1), size(m,2));
    for ii = 1:size(m,1)
        for jj = 1:size(m,2)
            
            A = [track_diff(j,1) track_diff(j,2)];
            B = [flow(j).vx(ii,jj) flow(j).vy(ii,jj)];
            
            cosine(ii,jj) = dot(A,B)./ (norm(A) .*  norm(B));
            
        end
    end
    
    % Find dudx, dvdy
    dudx = zeros(size(cosine));
    dvdy = zeros(size(cosine));
    
    for ii = dy+1:dy:size(currentFrame, 1)-dy
        for jj = dx+1:dx:size(currentFrame, 2)-dx
            dudx(ii, jj) = (cosine(ii, jj+dx) - cosine(ii, jj-dx)) / 2 * dx;
            dvdy(ii, jj) = (cosine(ii+dy, jj) - cosine(ii-dy, jj)) / 2 * dy;
            
        end
    end
    
    G = hypot(dudx,dvdy);
    
    if dx ~= 1 || dy ~= 1
        [X0, Y0] = meshgrid(dx+1:dx:size(currentFrame,2)-dx, dy+1:dy:size(currentFrame, 1)-dy);
        [X, Y] = meshgrid(1:size(currentFrame,2), 1:size(currentFrame,2));
        G = G(dy+1:dy:size(currentFrame, 1)-dy, ...
            dx+1:dx:size(currentFrame, 2)-dx);
        G = interp2(X0, Y0, G, X, Y, 'cubic');
    end
    
    G = G .* cellOutline;
    G(cellOutline == 0) = NaN;
    G = G / max(abs(G(:)));
    
    % find max 3 sinks coordinates by sorting frequency field
    stream_f = stream(j).f(:);
    [stream_f_sorted, stream_f_sorted_index] = sort(stream_f, 'descend');
    
    if isempty(stream_f) ~= 1
        if length(stream_f) >= 3
            
            s1_x = stream(j).xf(stream_f_sorted_index(1),1);
            s1_y = stream(j).yf(stream_f_sorted_index(1),1);
            s2_x = stream(j).xf(stream_f_sorted_index(2),1);
            s2_y = stream(j).yf(stream_f_sorted_index(2),1);
            s3_x = stream(j).xf(stream_f_sorted_index(3),1);
            s3_y = stream(j).yf(stream_f_sorted_index(3),1);
            
            % calculate div in boxes around sinks
            s1_box_x = round(s1_x-(dx/2));
            s1_box_y = round(s1_y-(dy/2));
            s2_box_x = round(s2_x-(dx/2));
            s2_box_y = round(s2_y-(dy/2));
            s3_box_x = round(s3_x-(dx/2));
            s3_box_y = round(s3_y-(dy/2));
            
            if isnan(s1_box_x)  % verify sink it's not at the cell edge
                s1_grad = zeros(dx+1, dy+1) * NaN;
            else
                s1_grad = G(s1_box_y:s1_box_y+dy, s1_box_x:s1_box_x+dx);
            end
            
            if isnan(s2_box_x)
                s2_grad = zeros(dx+1, dy+1) * NaN;
            else
                s2_grad = G(s2_box_y:s2_box_y+dy, s2_box_x:s2_box_x+dx);
            end
            
            if isnan(s3_box_x)
                s3_grad = zeros(dx+1, dy+1) * NaN;
            else
                s3_grad = G(s3_box_y:s3_box_y+dy, s3_box_x:s3_box_x+dx);
            end
            
            grad_at_sink(j,1) = nanmean(s1_grad(:));
            grad_at_sink(j,2) = nanmean(s2_grad(:));
            grad_at_sink(j,3) = nanmean(s3_grad(:));
            
        elseif length(stream_f) == 2
            
            s1_x = stream(j).xf(stream_f_sorted_index(1),1);
            s1_y = stream(j).yf(stream_f_sorted_index(1),1);
            s2_x = stream(j).xf(stream_f_sorted_index(2),1);
            s2_y = stream(j).yf(stream_f_sorted_index(2),1);
            
            % calculate div in boxes around sinks
            s1_box_x = round(s1_x-(dx/2));
            s1_box_y = round(s1_y-(dy/2));
            s2_box_x = round(s2_x-(dx/2));
            s2_box_y = round(s2_y-(dy/2));
            
            if isnan(s1_box_x)  % verify sink it's not at the cell edge
                s1_grad = zeros(dx+1, dy+1) * NaN;
            else
                s1_grad = G(s1_box_y:s1_box_y+dy, s1_box_x:s1_box_x+dx);
            end
            
            if isnan(s2_box_x)
                s2_grad = zeros(dx+1, dy+1) * NaN;
            else
                s2_grad = G(s2_box_y:s2_box_y+dy, s2_box_x:s2_box_x+dx);
            end
            
            grad_at_sink(j,1) = nanmean(s1_grad(:));
            grad_at_sink(j,2) = nanmean(s2_grad(:));
            
        elseif length(stream_f) == 1
            
            s1_x = stream(j).xf(stream_f_sorted_index(1),1);
            s1_y = stream(j).yf(stream_f_sorted_index(1),1);
            
            % calculate div in boxes around sinks
            s1_box_x = round(s1_x-(dx/2));
            s1_box_y = round(s1_y-(dy/2));
            
            if isnan(s1_box_x)  % verify sink it's not at the cell edge
                s1_grad = zeros(dx+1, dy+1) * NaN;
            else
                s1_grad = G(s1_box_y:s1_box_y+dy, s1_box_x:s1_box_x+dx);
            end
            
            grad_at_sink(j,1) = nanmean(s1_grad(:));
            
        end
    end
    
    clear stream_f
    clear s1_grad s2_grad s3_grad
    clear s1_x s1_y s2_x s2_y s3_x s3_y
    
end

average_grad_at_sink = nanmean(grad_at_sink);

%% SAVE %%
save(fullfile(d, 'data', ...
    ['gradient_sinks_', output_name, '.mat']), ...
    'grad_at_sink');

save(fullfile(d, 'data', ...
    ['gradient_sinks_average_', output_name, '.mat']), ...
    'average_grad_at_sink');

clear