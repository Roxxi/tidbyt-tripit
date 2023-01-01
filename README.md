# What do events look like coming back from an .ics?

```
BEGIN:VEVENT
DTSTAMP:20221228T224405Z
SUMMARY:Check-out: Tuscany Suites and Casino
TRANSP:TRANSPARENT
UID:item-3c9b96df-4b6f-9000-0003-0000e9d77c45@tripit.com
DTSTART:20230605T180000Z
DTEND:20230605T190000Z
LOCATION:Tuscany Suites and Casino\, 255 East Flamingo Road | Las Vegas\, 
 NV\, 89169
DESCRIPTION:View and/or edit details in TripIt : https://www.tripit.com/tr
 ip/show/id/326640882\n \n\n11:00 AM PDT\n[Lodging] Depart Tuscany Suites a
 nd Casino\nCheck-Out: 11:00am\nTuscany Suites and Casino\, 255 East Flamin
 go Road | Las Vegas\, NV\, 89169\n1-877-887-2261\nConfirmation # L72DAQVHX
 B\n \n\n \nTripIt - organize your travel at https://www.tripit.com
GEO:36.1134337;-115.1602397
END:VEVENT

```



# How do we identify trips from the ics?

`curl
https://www.tripit.com/feed/ical/private/E1043D3B-49B296C0DCB609CB06C72AF385618C69/tripit.ics
| grep "UID" | grep -v "item"`

_All of the Events who have UUIDs that aren't itinerary items have
UIDs that do not start with `item`_

# How do we put together events?

1. We fetch the data from the `.ics` URL
2. We read line by line creating a new dictionary entry every time we
   see `BEGIN:VEVENT`, parse each line into a key/value pair that is
   insered into a dictionary until we get to `END:VEVENT`
3. We are done reading once we get to `END:VCALENDAR`

# How do we get the event name and start time?

* Event name: `SUMMARY:<...>`
* Start Time: `DTSTAMP:20221228T224405Z`

# How do we calculate the countdown?

* DATE(_Event Start Time_) - DATE(_Today_)

