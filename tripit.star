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
TRIPIT_CLIENT_SECRET = 

def actual_now(config):
    timezone = config.get("timezone") or "America/Los_Angeles"
    return time.now().in_location(timezone)

def oauth_handler(params):
    params = json.decode(params)

    res = http.post(
        url = "https://app.pagerduty.com/oauth/token",
        headers = {
            "Accept": "application/json",
        },
        form_body = dict(
            params,
            client_secret = ,
        ),
        form_encoding = "application/x-www-form-urlencoded",
    )

    if res.status_code != 200:
        fail("token request failed with status code: %d - %s" %
             (res.status_code, res.body()))

    token_params = res.json()
    access_token = token_params["access_token"]

    return access_token

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.OAuth2(
                id = "auth",
                name = "PagerDuty",
                desc = "Connect your PagerDuty account.",
                icon = "pager",
                handler = oauth_handler,
                client_id = PAGERDUTY_CLIENT_ID,
                authorization_endpoint = "https://app.pagerduty.com/oauth/authorize",
                scopes = [
                    "read",
                ],
            ),
        ]
    )


def main(config):

    return render.Root(
        delay = 5000,
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

