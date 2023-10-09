import os
folder="/root/downloads"
 
# list to store files
res = []

# Iterate directory
for path in os.listdir(folder):
    # check if current path is a file
    if os.path.isfile(os.path.join(dir_path, path)):
        res.append(path)
print(res)