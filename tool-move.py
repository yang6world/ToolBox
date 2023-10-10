import os
import fuzzywuzzy
import shutil
 
dir_path = r'/root'
end_path = r'/root/data'
#遍历所有文件
def get_file_list(dir_path):
    all = os.listdir(dir_path)
    for i in all:
        if i.startswith('.'):
            all.remove(i)
    file = []
    for path in os.listdir(dir_path):
        if os.path.isfile(os.path.join(dir_path, path)):
            file.append(path)
    for i in file:
        if i.startswith('.'):
            file.remove(i)
    folder = []
    for path in os.listdir(dir_path):
        if os.path.isdir(os.path.join(dir_path, path)):
            folder.append(path)
    for i in folder:
        if i.startswith('.'):
            folder.remove(i)
    return all,file,folder

all,file,folder=get_file_list(dir_path+'/'+'config')
#文件树比较并进行移动操作
def compare_file(dir_path,end_path):
    num=0
    first_start_all,first_start_file,first_start_folder=get_file_list(dir_path)
    first_end_all,first_end_file,first_end_folder=get_file_list(end_path)
    for i in first_start_file:
        for j in first_end_file:
            secend_start_all,secend_start_file,secend_start_folder=get_file_list(dir_path+'/'+i)
            secend_end_all,secend_end_file,secend_end_folder=get_file_list(end_path+'/'+j)
            if not secend_start_all:
                print(dir_path+'为空')
                break
            if not secend_start_folder:
                print(dir_path+'为空')
                
            else:
                _,_,_=compare_file(dir_path+'/'+i,end_path)
            if fuzzywuzzy.fuzz.ratio(i,j)>80:
                #判断first_start_file列表是否为空
                if not first_start_folder:
                    print('first_start_file列表为空')
                    break
                else:
                    for k in secend_start_file:
                        num=num+1
                        formatted_number = str(num).zfill(2)
                        _,source_file,_=dir_path+'/'+i+'/'+k
                        source_file=dir_path+'/'+i
                        destination_folder=end_path+'/'+j
                        new_destination_path = os.path.join(destination_folder, )
                        shutil.move(source_file, new_destination_path)
            else:
                break
print(all)
print(file)
print(folder)
i='/'+'电影'
print(dir_path+i)
