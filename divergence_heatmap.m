%% INPUT %%
% get the file directory
uiwait(msgbox('Load cell movie folder'));
d = uigetdir('');
listing = dir (fullfile (d, 'cb*.tif'));
numFiles = length (listing);

% ask the user for an ouput stamp
prompt = {'Provide a name for the output files', 'Movie ID (n) if file format is cb_(n)_m.tif'};
title = 'Parameters';
dims = [1 35]; % set input box size
user_answer = inputdlg(prompt,title,dims); % get user answer
output_name = (user_answer{1,1});
cell_ID = str2double(user_answer{2,1});

% parameters
dx = 5;
dy = 5;
dilationSize = 4;
erosionSize = 12;
connectivityFill = 4;
min_colorscale = 0;
max_colorscale = 5;

% load interpolated filed 
flow = load (fullfile ([d '/data'], ['piv_field_interpolated_', output_name, '.mat']));
flow = flow.vfilt;

% number of frames in the movie
nt = length(imfinfo(fullfile (d, sprintf('cb%d_m.tif', cell_ID))));

%% DIVERGENCE %%

for jj = 1:nt-1
    
    currentFrame = double(imread(fullfile(d, sprintf ...
        ('cb%d_m.tif', cell_ID)),jj)) / 255;
    
    nextFrame = double(imread(fullfile(d, sprintf ...
        ('cb%d_m.tif', cell_ID)),jj+1)) / 255;
    
    % Find didx, didy, dudx, dvdy
    u = flow(jj).vx;
    v = flow(jj).vy;
    
    dudx = zeros(size(u));
    dvdy = zeros(size(v));
    
    for i = dy+1:dy:size(currentFrame, 1)-dy
        for j = dx+1:dx:size(currentFrame, 2)-dx
            dudx(i, j) = (u(i, j+dx) - u(i, j-dx)) / 2 * dx;
            dvdy(i, j) = (v(i+dy, j) - v(i-dy, j)) / 2 * dy;
        end
    end
    
    % Compute net turnover
    div = dudx + dvdy;
    
    cellOutline1 = detectObjectBw(currentFrame, dilationSize, erosionSize, connectivityFill);
    cellOutline2 = detectObjectBw(nextFrame, dilationSize, erosionSize, connectivityFill);
    
    cellOutline = cellOutline1 .* cellOutline2;
    
    if dx ~= 1 || dy ~= 1
        [X0, Y0] = meshgrid(dx+1:dx:size(currentFrame,2)-dx, dy+1:dy:size(currentFrame, 1)-dy);
        [X, Y] = meshgrid(1:size(currentFrame,2), 1:size(currentFrame,2));
        turnover = div(dy+1:dy:size(currentFrame, 1)-dy, ...
            dx+1:dx:size(currentFrame, 2)-dx);
        div = interp2(X0, Y0, turnover, X, Y, 'cubic');
        
    end
    
    convergence = div;
    %     norm_convergence = convergence / max(abs(div(:)));
    
    convergence = convergence .* cellOutline; % mask for cell region
    convergence(convergence > 0 & cellOutline == 1) = 0; % if positive and within cell region make 0
    convergence(cellOutline == 0) = NaN; % if outside cell region make NaN (so that it can be turned black when plotting)
    convergence = abs(convergence); % make all negative to positive
    
    % plot heatmap
    h = imshow(convergence, []);
    colormap('jet');
    caxis([min_colorscale, max_colorscale])
    hold on
    
    % black background
    set(h, 'AlphaData', ~isnan(convergence)) % set NaN to transparent
    axis on;
    set(gca, 'XColor', 'none', 'yColor', 'none', 'xtick', [], 'ytick', [], 'Color', 'k') % turn transparent to black
    hold off
    
    % get frame for .tif saving
    im_out = getframe(gcf);
    im_out = im_out.cdata;
    
    % save .tif stack of convergence map
    imwrite(im_out, fullfile([d '/images'], ['divergence_heatmap_', output_name, '.tif']), ...
        'writemode', 'append');
end
close all;

