function add_folder_to_path(folder)
    if ispc
        NotinPath = isempty(strfind(lower(path),lower(folder)));
    else
        NotinPath = isempty(strfind(path,folder));
    end

    if exist(folder,'dir') == 7 && NotinPath
        addpath(folder);
    end
end