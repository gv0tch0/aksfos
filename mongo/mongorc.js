prompt = function() {
    result = "mongo-v" + db.version()
             + "@" + db.serverStatus().host + " "
             + "(db:" + db + ")";
    ismaster = db.isMaster();
    setname = ismaster.setName;
    if (setname != undefined) {
        result += " [" + setname + ":";
        iamprimary = ismaster.me == ismaster.primary;
        if (iamprimary) {
            result += "PRIMARY]> ";
        }
        else if (ismaster.secondary) {
            result += "SECONDARY]> ";
        }
        else {
            result += "ARBITER]> ";
        }
    }
    else {
        result += "> ";
    }
    return result;
}
