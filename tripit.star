"""
Applet: TripIt
Summary: Day-Countdown to next trip in TripIt
Description: Show a countdown of days to the next trips in TripIt
Author: github.com/roxxi
"""

load("cache.star", "cache")
load("encoding/json.star", "json")
load("humanize.star", "humanize")
load("http.star", "http")
load("time.star", "time")
load("schema.star", "schema")
load("secret.star", "secret")
load("render.star", "render")



DEFAULT_TIMEZONE = "America/Los_Angeles"
CONFIG_TRIPIT_ICS = "tripit-ics"


# TODO need to figure out if I need the timezone explicitly shared or not
def timezone(config):
    return config.get("timezone") or DEFAULT_TIMEZONE

def actual_now(config):
    return time.now().in_location(timezone(config))

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
        ]
    )



def parse_ics(ics):
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
            event["start_date"] = \
                l.removeprefix("DTSTART;VALUE=DATE:") \
                 .strip() \
                 .replace("\\n", "\n") \
                 .replace("\\", "")
        elif(l.startswith("DTEND;VALUE=DATE:")):
            event["end_date"] = \
                l.removeprefix("DTEND;VALUE=DATE:") \
                 .strip() \
                 .replace("\\n", "\n") \
                 .replace("\\", "")
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


def main(config):

    resp = http.get(config[CONFIG_TRIPIT_ICS])

    # TODO: This should be cached
    ics = resp.body()
    events = parse_ics(ics)
    # TODO - Filter events to events in the future
    # TODO - Next : transform each events raw data into displayable data
    # TODO - Display Data

    for e in events:
        print("Summary: %s\nDescription:\n%s" % \
              (e["summary"], e["description"]))

    return render.Root(
        delay = 500,
        child = render.Box(
            child = render.Animation(
                children = [
                    render.Text(
                        # content = actual_now(config).format("3:04 PM"),
                        content = "small steps lead to big changes",
                        font = "6x13",
                    ),
                    render.Text(
                        content = actual_now(config).format("3 04 PM"),
                        font = "6x13",
                    ),
                ],
            ),
        ),
    )

