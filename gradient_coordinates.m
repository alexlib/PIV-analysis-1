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
stream = load (fullfile ([d '/data'], ['flow_streamlines_endpts_erode_wcb_', output_name, '.mat']));
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
grad = zeros(nt-1,1) .* NaN;

%% find coordinates of max gradient %%
coord_max_grad = zeros(nt-1,2);
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
    
    [y, x] = find(G == max(G(:)));
    coord_max_grad(j,:) = [x y];
    
end

%% SAVE %%
save(fullfile(d, 'data', ...
    ['coord_max_gradient_', output_name, '.mat']), ...
    'coord_max_grad');

clear