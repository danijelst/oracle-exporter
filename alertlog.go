package main

import (
	"bufio"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/prometheus/common/log"
)

type Client struct {
	Ip   string `yaml:"ip"`
	Date string `yaml:"date"`
}

type Lastlog struct {
	Instance string   `yaml:"instance"`
	Clients  []Client `yaml:"clients"`
}

type Lastlogs struct {
	Cfgs []Lastlog `yaml:"lastlog"`
}

type oraerr struct {
	ora    string
	text   string
	ignore string
	count  int
}

var (
	Errors    []oraerr
	//oralayout = "Mon Jan 02 15:04:05 2006"
	oralayout = "2006-01-02T15:04:05.999999-07:00"
	lastlog   Lastlogs
)

// Get individual ScrapeTime per Prometheus instance for alertlog
func (e *Exporter) GetLastScrapeTime(conf int) time.Time {
	for i, _ := range lastlog.Cfgs {
		if lastlog.Cfgs[i].Instance == config.Cfgs[conf].Instance {
			for n, _ := range lastlog.Cfgs[i].Clients {
				if lastlog.Cfgs[i].Clients[n].Ip == e.lastIp {
					t, _ := time.Parse("2006-01-02 15:04:05 -0700 MST", string(lastlog.Cfgs[i].Clients[n].Date))
					return t
				}
			}
		}
	}
	return time.Now()
}

// Set individual ScrapeTime per Prometheus instance for alertlog
func (e *Exporter) SetLastScrapeTime(conf int, t time.Time) {
	var indInst int = -1
	var indIp int = -1
	for i, _ := range lastlog.Cfgs {
		if lastlog.Cfgs[i].Instance == config.Cfgs[conf].Instance {
			indInst = i
			for n, _ := range lastlog.Cfgs[i].Clients {
				if lastlog.Cfgs[i].Clients[n].Ip == e.lastIp {
					indIp = n
				}
			}
		}
	}
	if indInst == -1 {
		cln := Client{Ip: e.lastIp, Date: t.Format("2006-01-02 15:04:05 -0700 MST")}
		lastlog.Cfgs = append(lastlog.Cfgs, Lastlog{Instance: config.Cfgs[conf].Instance,
			Clients: []Client{cln}})
	} else {
		if indIp == -1 {
			cln := Client{Ip: e.lastIp, Date: t.Format("2006-01-02 15:04:05 -0700 MST")}
			lastlog.Cfgs[indInst].Clients = append(lastlog.Cfgs[indInst].Clients, cln)
		} else {
			lastlog.Cfgs[indInst].Clients[indIp].Date = t.Format("2006-01-02 15:04:05 -0700 MST")
		}
	}
}

func addError(conf int, ora string, text string) {
	var found bool = false
	for i, _ := range Errors {
		if Errors[i].ora == ora {
			Errors[i].count++
			found = true
		}
	}
	if !found {
		ignore := "0"
		for _, e := range config.Cfgs[conf].Alertlog[0].Ignoreora {
			if e == ora {
				ignore = "1"
			}
		}
		is := strings.Index(text, " ")
		ip := strings.Index(text, ". ")
		if is < 0 {
			is = 0
		}
		if ip < 0 {
			ip = len(text)
		}
		ora := oraerr{ora: ora, text: text[is+1 : ip], ignore: ignore, count: 1}
		log.Infoln("Adding error: ", ora)
		Errors = append(Errors, ora)
	}
}

func (e *Exporter) ScrapeAlertlog() {
	loc := time.Now().Location()
	re := regexp.MustCompile(`O(RA|GG)-[0-9]+`)
	log.Infoln("Time location", loc)
	ReadAccess()
	for conf, _ := range config.Cfgs {
		if len(config.Cfgs[conf].Alertlog) > 0 {

			var lastTime time.Time
			Errors = nil
			lastScrapeTime := e.GetLastScrapeTime(conf).Add(time.Second)

			log.Infoln("lastTime init", lastTime)
			log.Infoln("lastScrapeTime", lastScrapeTime)

			info, err := os.Stat(config.Cfgs[conf].Alertlog[0].File)
			file, err := os.Open(config.Cfgs[conf].Alertlog[0].File)
			if err != nil {
				log.Infoln(err)
			} else {
				scanner := bufio.NewScanner(file)
				for scanner.Scan() {
					t, err := time.ParseInLocation(oralayout, scanner.Text(), loc)
					log.Infoln("scanner.Text()", scanner.Text())
					log.Infoln("t", t)
					log.Infoln("err", err)
					if err == nil {
						lastTime = t
					} else {
						log.Infoln("comparing lastScrapeTime", lastScrapeTime)
						log.Infoln("comparing lastTime", lastTime)
						if lastTime.After(lastScrapeTime) {
							log.Infoln("comparing string", scanner.Text())
							if re.MatchString(scanner.Text()) {
								ora := re.FindString(scanner.Text())
								log.Infoln("matching ora", ora)
								addError(conf, ora, scanner.Text())
							}
						}
					}
				}
				e.SetLastScrapeTime(conf, lastTime)
				log.Infoln("lastTime", lastTime)
				for i, _ := range Errors {
					e.alertlog.WithLabelValues(config.Cfgs[conf].Database,
						config.Cfgs[conf].Instance,
						Errors[i].ora,
						strings.ToValidUTF8(Errors[i].text,""),
						Errors[i].ignore).Set(float64(Errors[i].count))
					WriteLog(config.Cfgs[conf].Instance + " " + e.lastIp +
						" (" + Errors[i].ignore + "/" + strconv.Itoa(Errors[i].count) + "): " +
						Errors[i].ora + " - " + Errors[i].text)
				}
				e.alertdate.WithLabelValues(config.Cfgs[conf].Database,
					config.Cfgs[conf].Instance).Set(float64(info.ModTime().Unix()))
			}

			if file != nil {
				file.Close()
			}
		}
	}
	WriteAccess()
}