##################################################################################
# City
# Name
# URL
# Notes
# License

## Initialize
root = "~/sites/falling-fruit-data/muni/"
file = ""
author = ""
setwd(root)
dt = load.data(file)


####
## Filter: Common name

# format Common
dt$Common = format.field(dt$COMMON)
dt$Common = capwords(dt$Common, strict = T, first = T)

# review
ddply(ddply(dt, .(Common), summarise, Count = length(Common)), .(Common))

# apply key (auto)
temp = filter.data.common(dt)


####
## Filter: Latin name

# format Common
dt$Common = format.field(dt$COMMON)
dt$Common = capwords(dt$Common, strict = T, first = T)

# format Scientific
dt$Scientific = format.field(dt$SCIENTIFIC, 'species')

# standardize Scientific
dt$Scientific_ori = dt$Scientific
# remove hybrid x (Genus 'x' species)
dt$Scientific = gsub("[ ]+[a-z][ ]+", " ", dt$Scientific, ignore.case=T)
# remove quotes around variety names
dt$Scientific = gsub("'($|[^s])", "\\1", dt$Scientific)

# review
ddply(ddply(dt, intersect(names(dt), c("Common", "Scientific")), summarise, Count = length(Scientific)), .(Scientific))

# apply key (auto)
temp = filter.data(dt, genus = T)


####
## Filter: Manual

keyfile = paste(dirname(file), '/', 'species.csv', sep  = '')
initialize.manual.key(temp, keyfile)
#temp = load.manual.key(temp, keyfile)


####
## Evaluate
fields = intersect(c("Scientific_ori","Scientific","Common","Type","Rating","Tag"), names(temp))

# missing info
ddply(temp[(temp["Type"] == "" & temp["Rating"] != -1) | (grepl("http", temp$Type, ignore.case = T)) | is.na(temp["Type"]),], fields, summarise, Count = length(Type))
# review
ddply(temp[temp["Rating"] == 1 & temp["Tag"] != 'bee',], fields, summarise, Count = length(Type))
ddply(temp[temp["Rating"] == 2 & temp["Tag"] != 'bee',], fields, summarise, Count = length(Type))
ddply(temp[temp["Rating"] > 0 & temp["Tag"] == 'bee',], fields, summarise, Count = length(Type))
ddply(temp[temp["Rating"] == -1,], fields, summarise, Count = length(Type))
ddply(temp, fields, summarise, Count = length(Type))

# trim
dt = temp[!is.na(temp$Type) & temp$Type != "" & !is.na(temp$Rating) & temp$Rating > 0,]
ddply(dt[fields], fields, summarise, Count = length(Type))


####
## Format fields

# format: unverified
if ("Unverified" %in% names(dt)) {
  ind = is.na(dt$Unverified) | dt$Unverified == ""
} else {
  ind = !vector(length = nrow(dt))
}
dt$Unverified[ind] = ""
uind = grepl("[ ]+sp$",dt$Scientific[ind],ignore.case=T)
nind = dt$Human[ind] == 1 | dt$Human[ind] == -1
dt$Unverified[ind][uind & !nind] = "x"
fields = intersect(c("Scientific_ori","Common","Scientific","Type","Unverified","Human"),names(dt))
unique(dt[order(dt$Unverified,decreasing=T),fields])

# format: description
if ("Description" %in% names(dt)) {
  ind = is.na(dt$Description) | dt$Description == ""
} else {
  ind = !vector(length = nrow(dt))
}
if (all(c("Common","Scientific_ori") %in% names(dt))) {
	dt$Description[ind] = paste(dt$Common[ind]," (",dt$Scientific_ori[ind],")",sep="")
} else {
	field = intersect(names(dt),c("Scientific_ori","Common"))
	dt$Description[ind] = dt[ind, field]
}
sort(unique(dt$Description))

# format: access
dt$Access = NA

# format: author
dt$Author = author

# format: notes
dt$Notes = NA
sort(unique(dt$Notes))

# format: address
addressCol = ""
streetCol = ""
cityString = ""
dt$Street = format.field(dt[,streetCol], 'address')
dt$Address = paste(dt[,addressCol], " ", dt$Street, ", ", cityString, sep = "")
sort(unique(dt$Address))


####
## Flatten
fdt = flatten.data(dt)
unique(fdt[c("Type","Description")])

####
## Export
export.data(fdt, file, dropfields = T)

####
## Summary (human)
ind = dt$Human > 0
fields = intersect(c("Scientific","Type","Human"),names(dt))
sdt = ddply(ddply(dt[ind, fields], fields, summarise, Count = length(Type)), .(Human)); sdt
shfile = paste(dirname(file), '/', 'summary_human.csv', sep  = '')
write.csv(sdt, shfile, row.names = F)