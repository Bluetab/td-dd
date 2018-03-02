
with open("data_structures.csv", "w") as ds_file:
    with open("data_fields.csv", "w") as fs_file:
        for i in xrange(1000):
            ds_file.write("system" +  str(i) + ",group" + str(i) + ",name" + str(i) + ",description" + str(i) + "\n")
            for j in xrange(50):
                fs_file.write("system" +  str(i) + ",group" + str(i) + ",name" + str(i) + ",name" + str(j) + ",type" + str(j) + ",description" + str(j) + "," + str(j%2) + "," + str(j) +  "\n")
