require!<[fs mkdirp moment optimist sha1 winston ../lib/util]>

updateName = (law, new_name, date) ->
    for name in law.name
        if name.name == new_name
            if moment date .isBefore name.start_date
                name.start_date = date
            return
    law.name.push { name: new_name, start_date: date }

updateHistory = (law, date, reason) ->
    if law.history[date] != void
        if law.history[date] != reason
            law.history[date] .= "\n#reason"
        return
    law.history[date] = reason

updateArticle = (law, date, article_no, content) ->
    if law.article[date] == void
        law.article[date] = {}
    digest = sha1 content
    law.article[date][article_no] = digest
    law.content[digest] = content

fixupData = (law, opts) ->
    if law.lyID == \90077
        law.name.push do
            name: \外交部特派員公署組織條例
            start_date: \1943-08-28

    law.PCode = opts.lookupPCode law
    law

parseHTML = (path, opts) ->
    law =
        name: []
        history: {}
        article: {}
        content: {}

    for file in fs.readdirSync path
        if /\d+\.htm/ != file
            continue
        winston.info "Process #path/#file"

        html = fs.readFileSync "#path/#file"

        var passed_date

        article_no = "1"
        var article
        articleStart = false

        var date
        var reason

        for line in html / '\n'
            match line
            | /<title>法編號:(\d{5})\s+版本:(\d{3})(\d{2})(\d{2})\d{2}/
                # 版本是 民國年(3) + 月(2) + 日(2) + 兩數字 組成
                # We use ISO-8601 format as statute version
                law.lyID = that.1
                passed_date = util.toISODate that.2, that.3, that.4

                winston.info "Match lyID #{law.lyID}, version #{passed_date}"

            | /<FONT COLOR=blue SIZE=5>([^(（]+)/
                name = that.1
                winston.info "Found name: #name"
                updateName law, that.1, passed_date

            | /<font size=2>(中華民國 \d+ 年 \d+ 月 \d+ 日)(.*)?<\/font/
                if date and reason
                    updateHistory law, date, reason
                    date = void
                    reason = void

                if date
                    winston.warn "Found orphan date: #date"
                date = util.toISODate that.1
                winston.info "Found date #date"

                if that.2
                    if reason
                        winston.warn "Found orphan reason: #reason"
                    reason = that
                    winston.info "Found reason #reason"

                    updateHistory law, date, reason

                    date = void
                    reason = void

            | /^<td valign=top><font size=2>(.+)<\/font/
                if reason
                    winston.warn "Found orphan reason: #reason"

                reason = that.1
                winston.info "Found reason: #reason"

                if not date
                    winston.warn "Found reason: #reason without date"

                updateHistory law, date, reason

                date = void
                reason = void

            | /^<td valign=top><font size=2>([^<]+)<br/
                content = that.1
                winston.info "Found start of partial reason: #content"
                if reason
                    winston.warn "Found orphan reason: #reason"

                reason = content

            # http://law.moj.gov.tw/LawClass/LawSearchNo.aspx?PC=A0030133&DF=&SNo=8,9
            #
            # Some articles does not start with \u3000\u3000, thus they look
            # identical to the partial reason. Because of this, we use
            # articleStart here to distinguish article content and partial
            # reason.
            | /^\u3000*([^<\u3000]+)<br>(.*)$/
                content = that.1
                tail = that.2
                if articleStart
                    winston.info "Match article content"
                    if article == void
                        article =
                            no: article_no
                            content: ''
                    article.content += content + '\n'
                    article_no = 1 + parseInt article_no, 10
                else
                    winston.info "Found partial reason: #content"
                    if not reason
                        winston.warn "Found partial reason without start: #content"

                    reason += '\n' + content

                    if tail
                        tail = tail.replace '<br>', '\n'
                        reason += tail

            | /^([^<\u3000]+)<\/font/
                content = that.1
                winston.info "Found end of partial reason: #content"
                if not reason
                    winston.warn "Found partial reason without start: #content"

                reason += '\n' + content

                updateHistory law, date, reason

                date = void
                reason = void

            | /<font color=blue size=4>民國\d+年\d+月\d+日/
                articleStart = true

            | /<font color=8000ff>第(.*)條(?:之(.*))?/
                if article
                    updateArticle law, passed_date, article.no, article.content

                article_no = util.parseZHNumber that.1 .toString!
                if that.3
                    article_no += "-" + util.parseZHNumber that.3 .toString!

                winston.info "Found article number #article_no"

                article =
                    no: article_no
                    content: ''

            | /^</
                if article and article.content != ""
                    updateArticle law, passed_date, article.no, article.content
                    article = void

        if date or reason
            winston.warn "Found orphan date: #date or reason: #reason"

        if article
            updateArticle law, passed_date, article.no, article.content

    fixupData law, opts

createPCodeMapping = (path, callback) ->
    err, data <- fs.readFile path
    if err => return callback err
    data = JSON.parse data
    ret = {}
    for index, item of data
        ret[item.name] = item.PCode
    callback null, ret

createLookupPCodeFunc = (path, callback) ->
    err, pcodeMapping <- createPCodeMapping path
    if err => return callback err
    callback null, (law) ->
        for i, item of law.name
            if pcodeMapping[item.name] != void => return pcodeMapping[item.name]
        switch law.lyID
        | \04507 => fallthrough
        | \04509 => fallthrough
        | \04511 => fallthrough
        | \04513 => fallthrough
        | \04515 => \B0000001
        | \04311 => \A0020001
        | \04318 => \D0020053
        |_ => void

main = ->
    argv = optimist .default {
        rawdata: "#__dirname/../rawdata/utf8_lawstat/version2"
        data: "#__dirname/../data/law"
        pcode: "#__dirname/../data/pcode.json"
    } .boolean \verbose .alias \v, \verbose
        .argv

    winston.clear!

    if not argv.verbose
        winston
            .add winston.transports.Console, { level: \warn }

    err, lookupPCode <- createLookupPCodeFunc argv.pcode
    if err => winston.warn err; lookupPCode = -> void

    for path in fs.readdirSync argv.rawdata
        indir = "#{argv.rawdata}/#path"
        m = path.match /([^/]+)\/?$/
        outdir = "#{argv.data}/#{m.1}"

        if not fs.statSync(indir).isDirectory() => continue

        winston.info "Process #indir"
        law = parseHTML indir, do
            lookupPCode: lookupPCode

        mkdirp.sync outdir
        winston.info "Write #outdir/law.json"
        fs.writeFileSync "#outdir/law.json", JSON.stringify law, '', 2

main!
