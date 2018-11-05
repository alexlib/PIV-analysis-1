%% INPUT %%

% get the file directory
uiwait(msgbox('Load cell movie folder'));
d = uigetdir('');

% ask the user for an ouput stamp
prompt = {'Provide a name for the output files', 'Movie ID (n) if file format is cb_(n)_m.tif', 'Max compression to be displayed in colourmap [A.U.]'};
title = 'Parameters';
dims = [1 35]; % set input box size
user_answer = inputdlg(prompt,title,dims); % get user answer
output_name = (user_answer{1,1});
cell_ID = str2double(user_answer{2,1});
max_colorscale = str2double(user_answer{3,1});

% load files
movieFilePath = [d sprintf('/cb%d_m.tif', mt)];

flowVelocity = load(fullfile ([d '/data'], ['piv_field_interpolated_', output_name, '.mat']));
flowVelocity = flowVelocity.vfilt;
nFrames = length(flowVelocity);
[height, width] = size(flowVelocity(1).vx);

% parameters
dx = 5; % width of the box used to compute the strain rate tensor
dy = 5; % height of the box used to compute the strain rate tensor
dt = 5;
gaussianFilterWidth = 5;
gaussianFilterHeight = 5;
dilationSize = 4;
erosionSize = 10;
connectivityFill = 4;
min_colorscale = 0;

%% COMPUTE STRAIN RATE TENSOR

yStep = ceil(dy/2);
xStep = ceil(dx/2);

strainRateTensor = [];

for k = 1:nFrames
    u = flowVelocity(k).vx;
    v = flowVelocity(k).vy;
    for y = 1+dy+yStep:dy:height-yStep-dy
        for x = 1+dx+xStep:dx:width-xStep-dx
            % Mean flow velocity in the next boxes
            u11 = mean(u(y+dy-yStep:y+dy+yStep, x-xStep:x+xStep));
            u11 = mean(u11(:));
            v11 = mean(v(y+dy-yStep:y+dy+yStep, x-xStep:x+xStep));
            v11 = mean(v11(:));
            
            u12 = mean(u(y-dy-yStep:y+dy+yStep, x-xStep:x+xStep));
            u12 = mean(u12(:));
            v12 = mean(v(y-dy-yStep:y+dy+yStep, x-xStep:x+xStep));
            v12 = mean(v12(:));
            
            % Mean flow velocity in the previous boxes
            u13 = mean(u(y-yStep:y+dy+yStep, x+dx-xStep:x+dx+xStep));
            u13 = mean(u13(:));
            v13 = mean(v(y-yStep:y+dy+yStep, x+dx-xStep:x+dx+xStep));
            v13 = mean(v13(:));
            
            u14 = mean(u(y-yStep:y+dy+yStep, x-dx-xStep:x-dx+xStep));
            u14 = mean(u14(:));
            v14 = mean(v(y-yStep:y+dy+yStep, x-dx-xStep:x-dx+xStep));
            v14 = mean(v14(:));
            
            % Compute the velocity Jacobian
            jacobian = [(u13-u14) / (2*dx), (u11-u12) / (2*dy);
                (v13-v14) / (2*dx), (v11-v12) / (2*dy)];
            
            % Find the strain rate as the symmetric part of the Jacobian
            strainRate = 0.5 * (jacobian + jacobian');
            
            % Append the strain rate tensor
            strainRateTensor(k).values(y, x, :, :) = strainRate;
            
            % Compute principal strain rate
            [V, D] = eig(strainRate);
            strainRateTensor(k).principalComponentsDirections(y, x, :, :) = V;
            strainRateTensor(k).principalComponentsValues(y, x, :) = diag(D);
        end
    end
    % Interpolate principcal strain rate values. The heatmap of the principal component values along
    % the major axis will show where are the regions with the most activity, either compression or tension.
    if dx ~= 1 || dy ~= 1
        [X0, Y0] = meshgrid(1+dx+xStep:dx:width-xStep-dx, ...
            1+dy+yStep:dy:height-yStep-dy);
        [X, Y] = meshgrid(1:width, 1:height);
        strainRate = strainRateTensor(k).principalComponentsValues(1+dy+yStep:dy:height-yStep-dy, ...
            1+dx+xStep:dx:width-xStep-dx, 1);
        strainRateTensor(k).interpolatedPrincipalComponentsValues = interp2(X0, Y0, strainRate, X, Y, 'cubic');
%         strainRateTensor(k).interpolatedPrincipalComponentsValues = ...
%             strainRateTensor(k).interpolatedPrincipalComponentsValues / ...
%             max(abs(strainRateTensor(k).interpolatedPrincipalComponentsValues(:)));
        strainRate = strainRateTensor(k).principalComponentsValues(1+dy+yStep:dy:height-yStep-dy, ...
            1+dx+xStep:dx:width-xStep-dx, 2);
        strainRateTensor(k).interpolatedPrincipalComponentsValues2 = interp2(X0, Y0, strainRate, X, Y, 'cubic');
%         strainRateTensor(k).interpolatedPrincipalComponentsValues2 = ...
%             strainRateTensor(k).interpolatedPrincipalComponentsValues2 / ...
%             max(abs(strainRateTensor(k).interpolatedPrincipalComponentsValues2(:)));
     end
end

%% VISUALIZE HEATMAPS OF INTERPOLATED PRINCIPAL STRAIN RATES

for k = 1:nFrames
    
    % load movie frames
    currentFrame = double(imread(movieFilePath, k))/255;
    nextFrame = double(imread(movieFilePath, k+1))/255;
    
    % detect cell outline and common region between frames
    cellOutline1 = detectObjectBw(currentFrame, dilationSize, erosionSize, connectivityFill);
    cellOutline2 = detectObjectBw(nextFrame, dilationSize, erosionSize, connectivityFill);
    cellOutline = cellOutline1 .* cellOutline2;

    % filter intensity with a low pass gaussian filter
    currentFrameFilt = imgaussfilt(currentFrame,...
        'FilterSize', [gaussianFilterWidth, gaussianFilterHeight]);
    nextFrameFilt = imgaussfilt(nextFrame, ...
        'FilterSize', [gaussianFilterWidth, gaussianFilterHeight]);

    % compute values for heatmap
    vals = strainRateTensor(k).interpolatedPrincipalComponentsValues;
    vals = vals .* cellOutline;     % mask for common region
    
    vals(vals > 0 & cellOutline == 1) = 0;	% set positive values to 0 in the cell region
    vals(cellOutline == 0) = NaN;           % set everything outside the cell region to NaN (it can be turned black for plot)
    vals = abs(vals);                       % negative to positive vals
    
    % vals = vals /  max(abs(vals(:))); % normalise for max value
   
    % plot heatmap
    h = imshow(vals,[]);
    colormap('jet');
    caxis([min_colorscale, max_colorscale])
    c = colorbar;
    c.Label.FontSize = 14;
    c.Label.String = 'Compression (A.U.)';
    hold on
    
    % black background
    set(h, 'AlphaData', ~isnan(vals))
    axis on;
    set(gca, 'XColor', 'none', 'yColor', 'none', 'xtick', [], 'ytick', [], 'Color', 'k')
    hold off
    
    % get current frame for save
    im_out = getframe(gcf);
    im_out = im_out.cdata;
    
    % save .tif stack
    imwrite(im_out, fullfile([d '/images'], ['principal_strain_rate_heatmap_', output_name, '.tif']), ...
        'writemode', 'append');
    
end
close all; clear