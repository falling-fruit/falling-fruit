root = '~/sites/falling-fruit/config/locales/'
file_in = 'en.yml'
file_out = 'en_new.yml'

# load data 
library(base64enc)
setwd(root)
t = readChar(file_in, file.info(file_out)$size)

# search for !binary ".*"
temp = gregexpr("!binary \"[^\"]*", t)
start = as.numeric(temp[[1]])
stop = start + attr(temp[[1]], "match.length") - 1

# decode and replace
for (i in length(start):1) {
  s64 = substr(t, start[i] + 9, stop[i])
  s = rawToChar(base64decode(s64))
  t_end = nchar(t)
  t1 = substr(t, 1, start[i] - 1)
  t2 = substr(t, stop[i] + 2, t_end)
  t = paste(t1, s, t2, sep = "")
}

# output new file
writeChar(t, file_out)