"""
Applet: TripIt
Summary: Day-Countdown to next trip in TripIt
Description: Show a countdown of days to the next trips in TripIt
Author: github.com/roxxi
"""
load("encoding/json.star", "json")
load("cache.star", "cache")
load("re.star", "re")
load("humanize.star", "humanize")
load("http.star", "http")
load("time.star", "time")
load("schema.star", "schema")
load("render.star", "render")



DEFAULT_TIMEZONE = "America/Los_Angeles"
CONFIG_TRIPIT_ICS = "tripit-ics"
CONFIG_TZ = "timezone"


# TODO need to figure out if I need the timezone explicitly shared or not
def timezone(config):
    return config.get("timezone") or DEFAULT_TIMEZONE

def get_timezone(location):
    loc = json.decode(location)
    return [
        schema.Option(
            display = loc["timezone"],
            value = loc["timezone"],
        )
    ]

def actual_now(location):
    return time.now().in_location(location)

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = CONFIG_TRIPIT_ICS,
                name = "TripIt iCal Feed URL",
                desc = "Link to your TripIt iCal Feed from TripIt.com",
                icon = "calendar",
            ),
            schema.LocationBased(
                id = CONFIG_TZ,
                name = "Primary Timezone",
                desc = "Your Primary Timezone",
                icon = "clock",
                handler = get_timezone,
            ),
        ]
    )



def parse_ics(ics, location="UTC"):
    # we'll return this list of event dictionaries after parsing
    # out the trips (not every evernt)
    events = []

    # debugging
    num_begins = 0
    num_ends = 0

    skip = False # we want to skip events that ARE prefixed with `UID:item`
    event = {} # each iteration of the loop will build this event up
    multiline_mode = ""

    # TODO Refactor logic so that if skip = True we don't do
    #   the processing for those entries
    # TODO Look ahead and see if an entry has already passed.
    #   If so, we can also skip processing it
    for l in ics.splitlines():
        if (l.startswith("BEGIN:VEVENT")):
            skip == False
            event = {} # clear the event each time we see a new begin
            num_begins += 1
        elif (l.startswith("END:VEVENT") and skip == False):
            events.append(event) # add the completed event
            num_ends += 1
        elif (l.startswith("END:VEVENT") and skip == True):
            # we are explicity NOT adding the event to the events list
            # but now that we're done skipping, we can set skip to false again
            skip = False
            num_ends += 1
        elif (l.startswith("UID:item")):
            # skip until we see another UID that is not prefixed with item
            # "item" prefixed items are specific events within a trip
            # UIDs not prefixed by `item` are trip UIDs (i.e. containers)
            skip = True
        elif(l.startswith("UID:") and not l.startswith("UID:item")):
            skip = False
        elif(l.startswith("DTSTAMP:")):
            event["created_at"] = \
                l.removeprefix("DTSTAMP:") \
                 .strip() \
                 .replace("\\n", "\n") \
                 .replace("\\", "")
        elif(l.startswith("DTSTART;VALUE=DATE:")):
            d = l.removeprefix("DTSTART;VALUE=DATE:") \
                 .strip() \
                 .replace("\\n", "\n") \
                 .replace("\\", "")
            # d format "YYYYMMDD"
            event["start_date_raw"] = d
            event["start_date_parsed"] = \
                time.time(year = int(d[0:4]), \
                          month = int(d[4:6]), \
                          day = int(d[6:8]), \
                          location=location)
        elif(l.startswith("DTEND;VALUE=DATE:")):
            d= l.removeprefix("DTEND;VALUE=DATE:") \
                .strip() \
                .replace("\\n", "\n") \
                .replace("\\", "")
            # d format "YYYYMMDD"
            event["end_date_raw"] = d
            event["end_date_parsed"] = \
                time.time(year = int(d[0:4]), \
                          month = int(d[4:6]), \
                          day = int(d[6:8]), \
                          location=location)
        # SUMMARY:
        elif(l.startswith("SUMMARY:")):
            event["summary"] = \
                l.removeprefix("SUMMARY:") \
                 .strip() \
                 .replace("\\n", "\n") \
                 .replace("\\", "")
            multiline_mode = "summary"
        # DESCRIPTION:
        elif(l.startswith("DESCRIPTION:")):
            event["description"] = \
                l.removeprefix("DESCRIPTION:") \
                 .strip() \
                 .replace("\\n", "\n") \
                 .replace("\\", "")
            multiline_mode = "description"
        # LOCATION:
        elif(l.startswith("LOCATION:")):
            event["location"] = \
                l.removeprefix("LOCATION:") \
                 .strip() \
                 .replace("\\n", "\n") \
                 .replace("\\", "")
            multiline_mode = "location"
        # GEO:
        elif(l.startswith("GEO:")):
            event["geo"] = \
                l.removeprefix("GEO:") \
                 .strip() \
                 .replace("\\n", "\n") \
                 .replace("\\", "")
        # Multiline aggregtation
        elif(l.startswith(" ") and skip == False):
            merged_entry = event[multiline_mode] + l.strip()
            # we might be sowing together whitespace characters
            # that can be eliminated once they're merged
            cleaned_entry = merged_entry.replace("\\n", "\n").replace("\\", "")
            event[multiline_mode] = cleaned_entry
        else:
              pass

    # TODO: Add fail if num_begins != num_ends
    return events


def filter_future_events(events, location="UTC"):
    upcoming = []
    now = actual_now(location)
    for e in events:
        start = e["start_date_parsed"]
        duration =  start - now
        if any([duration.hours   >= 0, \
                duration.minutes >= 0, \
                duration.seconds >= 0,  ]):
            upcoming.append(e)
    return upcoming


def relative_to_abbreviated(relative_string):
    # The relative string looks like "5 months" or "10 days"
    # We want to extract it into "5m" or "10d"
    numbers = re.findall("\\d+", relative_string)
    number = numbers[0]
    unit_full = re.findall("[a-zA-Z]+", relative_string)
    unit_one = unit_full[0][0]
    return number+unit_one


def calculate_countdown(events, location="UTC"):
    now = actual_now(location)
    for e in events:
        start = e["start_date_parsed"]
        duration =  start - now
        e["countdown_duration"] = duration
        rs = humanize.relative_time(now, start)
        e["relative_string"] = rs
        e["relative_abbr"] = relative_to_abbreviated(rs)


def render_event(e):
    return render.Row(children = \
                      [render.Text(content = e["summary"] + ": ",
                                   font = "tb-8",
                                   ),
                       render.Text(content = \
                                   e["relative_abbr"],
                                   font = "tb-8",
                                   ),
                       ])

def main(config):

    ics_uri = config[CONFIG_TRIPIT_ICS]
    location = timezone(config)

    # TODO: This should be cached
    resp = http.get(ics_uri)
    ics = resp.body()
    events = parse_ics(ics, location)
    future_events = filter_future_events(events, location)
    calculate_countdown(future_events)

    rows = []
    for e in future_events:
        rows.append(render_event(e))

    # TODO: Needs to have two columns so I can align the text
    return render.Root(
        delay = 500,
        child = render.Column(children = rows))


