import os
import shutil
from fuzzywuzzy import fuzz

dir_path = r'/root'
end_path = r'/root/data'

def get_file_list(dir_path):
    all_entries = os.listdir(dir_path)
    all_entries = [entry for entry in all_entries if not entry.startswith('.')]
    
    files = [path for path in all_entries if os.path.isfile(os.path.join(dir_path, path))]
    folders = [path for path in all_entries if os.path.isdir(os.path.join(dir_path, path))]
    
    return all_entries, files, folders

def compare_file(dir_path, end_path):
    num = 0
    
    # 获取起始和结束路径的文件列表
    _, start_files, start_folders = get_file_list(dir_path)
    _, end_files, end_folders = get_file_list(end_path)
    
    for start_file in start_files:
        for end_file in end_files:
            # 使用模糊匹配判断文件名相似度是否大于80%
            if fuzz.ratio(start_file, end_file) > 80:
                # 构建源文件和目标文件夹路径
                source_file = os.path.join(dir_path, start_file)
                destination_folder = os.path.join(end_path, end_file)
                
                # 移动文件
                shutil.move(source_file, destination_folder)
                
                num += 1
                print(f"Moved: {start_file} to {end_file}")
                
                # 解析季数和集数
                season, episode = parse_season_and_episode(start_file)
                
                # 构建新文件名
                new_filename = f"{end_file}_S{season}_EP{episode}{get_file_extension(start_file)}"
                
                # 构建新文件的路径
                new_file_path = os.path.join(end_path, new_filename)
                
                # 重命名文件
                os.rename(destination_folder, new_file_path)
                
                print(f"Renamed: {end_file} to {new_filename}")
                
                # 退出内层循环，继续下一个文件
                break

    # 递归处理子文件夹
    for start_folder in start_folders:
        # 构建子文件夹的路径
        sub_dir_path = os.path.join(dir_path, start_folder)
        sub_end_path = os.path.join(end_path, start_folder)
        
        # 递归调用比较函数
        compare_file(sub_dir_path, sub_end_path)

def parse_season_and_episode(filename):
    # 假设文件名的格式为 "S01E02"，可以根据实际情况进行调整
    # 这里只是一个示例
    season = int(filename[1:3])
    episode = int(filename[4:6])
    return season, episode

def get_file_extension(filename):
    # 获取文件后缀
    return os.path.splitext(filename)[1]

all_entries, _, _ = get_file_list(os.path.join(dir_path, 'config'))

# 打印文件列表
print(all_entries)

# 调用比较函数
compare_file(dir_path, end_path)
