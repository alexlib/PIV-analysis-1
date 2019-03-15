%% INPUT %%

% Expects as input the folder containing a .tif stack
% of the entity used for tracking (e.g. magenta channel - nucleus, n#_m.tif)
% This should be masked in Fiji in order to have a white (255) object on a black (0) background

% get the file directory
uiwait(msgbox('Load cell movie folder'));
d = uigetdir('');

% ask the user for an ouput stamp
prompt = {'Provide a name for the output files', ...
    'Movie ID (n) if file format is n(n)_m.tif', ...
    'Pixel size [um]'};
title = 'Parameters';
dims = [1 35];
user_answer = inputdlg(prompt,title,dims);
output_name = (user_answer{1,1});
cell_ID = str2double(user_answer{2,1});
px_length = str2double(user_answer{3,1}); % [um]

file_name = sprintf('/n%d_m.tif', cell_ID);
nt = length(imfinfo(strcat(d, file_name)));

%% TRACKING %%

for k = 1:nt
    
    % read image at current frame
    im = imread(fullfile(d, file_name), k);
    
    % apply gaussian blur to smooth edges
    gauss = fspecial('gauss', [60 60], 60/6);
    im_tmp = imfilter(im, gauss);
    
    % create mask of the smoothed object
    BW1 = edge(im_tmp, 'Canny');                        % find object edge
    dilate_BW1 = imdilate(BW1, strel('disk', 4));       % dilate
    fill_BW1 = imfill(dilate_BW1, 8, 'holes');          % fill
    erode_BW1 = imerode(fill_BW1, strel('disk', 4));    % erode
    BW2 = bwareaopen(erode_BW1, 250, 8);                % remove all unconnected points
    
    % get centroid
    s = regionprops(BW2,'Centroid','Area');
    A = [s(:).Area];
    [~, idx] = max(A(:));   % save only centroid of the largest object 
    x = s(idx).Centroid(1,1);
    y = s(idx).Centroid(1,2);
    
    centre(k,:) = [x y]; % [px]
    
    imshow(BW2)
    hold on
    plot(centre(1:k, 1), centre(1:k, 2), '-m','LineWidth',3);
    drawnow
    hold off
    
end

path = centre * px_length; % [um]

%% SAVE %%

if ~exist(fullfile(d, 'data'), 'dir')
    mkdir(fullfile(d, 'data'));
end

save(fullfile(d, 'data', ...
    ['cell_track_', output_name, '.mat']), 'path');

clear
