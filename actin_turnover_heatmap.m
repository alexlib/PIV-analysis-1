%% INPUT %%

% get the file directory
uiwait(msgbox('Load cell movie folder'));
d = uigetdir('');

% ask the user for an ouput stamp
prompt = {'Provide a name for the output files', 'Movie ID (n) if file format is cb_(n)_m.tif', 'Max disassembly to be displayed in colourmap [A.U.]'};
title = 'Parameters';
dims = [1 35]; % set input box size
user_answer = inputdlg(prompt,title,dims); % get user answer
output_name = (user_answer{1,1});
cell_ID = str2double(user_answer{2,1});
max_colorscale = str2double(user_answer{3,1});

% parameters
dt = 5;
dx = 5;
dy = 5;
dilationSize = 4;
erosionSize = 12;
connectivityFill = 4;
min_colorscale = 0;

% load data
flow = load (fullfile ([d '/data'], ['piv_field_interpolated_', output_name, '.mat']));
flow = flow.vfilt;

nt = length(flow);

%% MASS TRANSFER (actin turnover) %%

for jj =  1:nt-1
    
    currentFrame = double(imread(fullfile(d, sprintf ...
        ('cb%d_m.tif', cell_ID)),jj)) / 255;
    
    nextFrame = double(imread(fullfile(d, sprintf ...
        ('cb%d_m.tif', cell_ID)),jj+1)) / 255;
    
    % Filter intensity with a low pass gaussian filter
    %         currentFrameFilt = imgaussfilt(currentFrame,gaussianFilterStd, 'FilterSize', [gaussianFilterWidth, gaussianFilterHeight]);
    %         nextFrameFilt = imgaussfilt(nextFrame,gaussianFilterStd, 'FilterSize', [gaussianFilterWidth, gaussianFilterHeight]);
    currentFrameFilt = imgaussfilt(currentFrame,16);
    nextFrameFilt = imgaussfilt(nextFrame,16);
    
    % Compute d(intensity)/d(t)
    didt = (nextFrameFilt - currentFrameFilt) / dt;
    
    % Find didx, didy, dudx, dvdy
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
            didx(i, j) = (currentFrameFilt(i, j+dx) - currentFrameFilt(i, j-dx)) / 2 * dx;
            didy(i, j) = (currentFrameFilt(i+dy, j) - currentFrameFilt(i-dy, j)) / 2 * dy;
        end
    end
    
    % Compute net turnover
    turnover = didt + currentFrame .* (dudx + dvdy) + u .* didx + v .* didy;
    
    % Eliminate any edge artefacts.
    % Find intersection between current and next cell outline
    
    cellOutline1 = detectObjectBw(currentFrame, dilationSize, erosionSize, connectivityFill);
    cellOutline2 = detectObjectBw(nextFrame, dilationSize, erosionSize, connectivityFill);
    
    cellOutline = cellOutline1 .* cellOutline2;
    
    % Interpolate net turnover to cover the full outline
    if dx ~= 1 || dy ~= 1
        [X0, Y0] = meshgrid(dx+1:dx:size(currentFrame,2)-dx, dy+1:dy:size(currentFrame, 1)-dy);
        [X, Y] = meshgrid(1:size(currentFrame,2), 1:size(currentFrame,2));
        turnover = turnover(dy+1:dy:size(currentFrame, 1)-dy, ...
            dx+1:dx:size(currentFrame, 2)-dx);
        interpolatedTurnover = interp2(X0, Y0, turnover, X, Y, 'cubic');
        
    end
    
    % compute values for heatmap
    disassembly = interpolatedTurnover;
    disassembly = disassembly .* cellOutline; %  mask for common cell region
    
    disassembly(disassembly > 0 & cellOutline == 1) = 0;	% set positive values to 0 in the cell region
    disassembly(cellOutline == 0) = NaN;                    % set everything outside the cell region to NaN (it can be turned black for plot)
    disassembly = abs(disassembly);                         % negative to positive vals
    
    % disassembly = disassembly /  max(abs(disassembly(:))); % normalise for max values
    
    % plot heatmap
    h = imshow(disassembly,[]);
    colormap('jet');
    caxis([min_colorscale, max_colorscale])
    c = colorbar;
    c.Label.FontSize = 14;
    c.Label.String = 'Disassembly (A.U.)';
    hold on
    
    % black background
    set(h, 'AlphaData', ~isnan(disassembly))
    axis on;
    set(gca, 'XColor', 'none', 'yColor', 'none', 'xtick', [], 'ytick', [], 'Color', 'k')
    hold off
    
    % get current frame for save
    im_out = getframe(gcf);
    im_out = im_out.cdata;
    
    % save .tif stack
    imwrite(im_out, fullfile([d '/images'], ['actin_turnover_heatmap_', output_name, '.tif']), ...
        'writemode', 'append');
end
close all; clear