#!/usr/bin/env python3
"""App Store Connect publishing for Folio, from the command line.

Adapted from the Entropic release tooling. Reads tools/asc/metadata.json and
talks to the App Store Connect API with a team key. Every step is idempotent:
run it again and it updates what exists. The app record itself has to be
created on the App Store Connect website; the API does not allow it.

Usage:
  publish.py --key-id KEY --issuer-id ISSUER --key-file AuthKey.p8 <command> [...]

Commands:
  info          Show the app record, versions, and builds
  metadata      Name is left as created; sets subtitle, privacy URL, categories,
                description, keywords, URLs, promotional text, what's new
  review        App Review contact and notes
  age-rating    Age rating declaration
  screenshots   Upload every PNG in marketing/store/<DISPLAY_TYPE>/ to that
                screenshot set (replaces each set)
  pricing       Free, available in every territory, content rights declared
  testflight    Wait for the newest build to process, attach it to the internal
                group, set what to test
  submit        Put the newest processed build (or ASC_BUILD=N) on the editable
                version and submit it for review; a submission already waiting
                is withdrawn first and its items carried over. Writes the
                release record under build/releases/<version>-<build>/
  all           metadata, review, age-rating, screenshots, pricing
"""
import argparse, hashlib, json, os, sys, time
from pathlib import Path

import jwt, requests

ROOT = Path(__file__).resolve().parents[2]
META = json.loads((Path(__file__).parent / "metadata.json").read_text())
# The App Review contact is kept out of the repository, in a local file next to this one.
CONTACT = Path(__file__).parent / "contact.local.json"
if CONTACT.exists():
    META["review"].update(json.loads(CONTACT.read_text()))
API = "https://api.appstoreconnect.apple.com"


class ASC:
    def __init__(self, key_id, issuer_id, key_file):
        self.key_id, self.issuer_id = key_id, issuer_id
        self.key = Path(key_file).read_text()
        self._token, self._token_at = None, 0

    def token(self):
        if time.time() - self._token_at > 15 * 60:
            now = int(time.time())
            self._token = jwt.encode(
                {"iss": self.issuer_id, "iat": now, "exp": now + 19 * 60, "aud": "appstoreconnect-v1"},
                self.key, algorithm="ES256", headers={"kid": self.key_id},
            )
            self._token_at = time.time()
        return self._token

    def call(self, method, path, **kw):
        url = path if path.startswith("http") else API + path
        headers = {"Authorization": f"Bearer {self.token()}"}
        if "json" in kw:
            headers["Content-Type"] = "application/json"
        r = requests.request(method, url, headers=headers, timeout=600, **kw)
        if r.status_code >= 400:
            raise RuntimeError(f"{method} {path} -> {r.status_code}: {r.text[:800]}")
        return r.json() if r.text else {}

    def get(self, path, **params):
        return self.call("GET", path, params=params)

    def get_all(self, path, **params):
        out, page = [], self.get(path, **params)
        while True:
            out += page.get("data", [])
            nxt = page.get("links", {}).get("next")
            if not nxt:
                return out
            page = self.call("GET", nxt)

    def post(self, path, type_, attributes=None, relationships=None):
        data = {"type": type_}
        if attributes:
            data["attributes"] = attributes
        if relationships:
            data["relationships"] = relationships
        return self.call("POST", path, json={"data": data})["data"]

    def patch(self, path, type_, id_, attributes=None, relationships=None):
        data = {"type": type_, "id": id_}
        if attributes:
            data["attributes"] = attributes
        if relationships:
            data["relationships"] = relationships
        return self.call("PATCH", path, json={"data": data}).get("data")

    def delete(self, path):
        return self.call("DELETE", path)


def rel(type_, id_):
    return {"data": {"type": type_, "id": id_}}


def upload_asset(asc, create_path, create_type, relationships, file_path, commit_type):
    """The three-step asset upload: reserve, PUT the parts, commit with checksum."""
    data = Path(file_path).read_bytes()
    reservation = asc.post(create_path, create_type,
                           {"fileName": Path(file_path).name, "fileSize": len(data)}, relationships)
    for op in reservation["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]: op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        r = requests.request(op["method"], op["url"], data=chunk, headers=headers, timeout=300)
        if r.status_code >= 400:
            raise RuntimeError(f"upload part failed: {r.status_code} {r.text[:300]}")
    asc.patch(f"/v1/{commit_type}/{reservation['id']}", create_type, reservation["id"],
              {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()})
    return reservation["id"]


# MARK: - Lookups

def app(asc):
    apps = asc.get("/v1/apps", **{"filter[bundleId]": META["bundleId"]})["data"]
    if not apps:
        sys.exit(f"No app record for {META['bundleId']} on this team. Create it in App Store Connect first.")
    return apps[0]


def editable_app_info(asc, app_id):
    infos = asc.get(f"/v1/apps/{app_id}/appInfos")["data"]
    for info in infos:
        if info["attributes"].get("appStoreState") in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "WAITING_FOR_REVIEW"):
            return info
    return infos[0]


def editable_version(asc, app_id):
    versions = asc.get(f"/v1/apps/{app_id}/appStoreVersions", **{"filter[platform]": "IOS"})["data"]
    for v in versions:
        if v["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "WAITING_FOR_REVIEW"):
            return v
    return asc.post("/v1/appStoreVersions", "appStoreVersions",
                    {"platform": "IOS", "versionString": META["version"]["versionString"]},
                    {"app": rel("apps", app_id)})


def localization(asc, parent_path, type_, parent_rel, attrs):
    """Find the locale's localization under a parent, else create it; then update."""
    existing = asc.get(parent_path)["data"]
    for loc in existing:
        if loc["attributes"]["locale"] == META["locale"]:
            return asc.patch(f"/v1/{type_}/{loc['id']}", type_, loc["id"], attrs)
    return asc.post(f"/v1/{type_}", type_, {**attrs, "locale": META["locale"]}, parent_rel)


# MARK: - Commands

def cmd_info(asc):
    a = app(asc)
    print(f"App: {a['attributes']['name']} ({a['id']}) bundle {a['attributes']['bundleId']}")
    for v in asc.get(f"/v1/apps/{a['id']}/appStoreVersions")["data"]:
        print(f"  version {v['attributes']['versionString']} {v['attributes']['platform']}: {v['attributes']['appStoreState']}")
    for b in asc.get("/v1/builds", **{"filter[app]": a["id"], "sort": "-uploadedDate", "limit": 5})["data"]:
        at = b["attributes"]
        print(f"  build {at['version']}: {at['processingState']} (uploaded {at['uploadedDate']})")


def cmd_metadata(asc):
    a = app(asc)
    info = editable_app_info(asc, a["id"])
    ai = META["appInfo"]
    localization(asc, f"/v1/appInfos/{info['id']}/appInfoLocalizations", "appInfoLocalizations",
                 {"appInfo": rel("appInfos", info["id"])},
                 {"subtitle": ai["subtitle"], "privacyPolicyUrl": ai["privacyPolicyUrl"]})
    categories = {"primaryCategory": rel("appCategories", ai["primaryCategory"])}
    if ai.get("secondaryCategory"):
        categories["secondaryCategory"] = rel("appCategories", ai["secondaryCategory"])
    asc.patch(f"/v1/appInfos/{info['id']}", "appInfos", info["id"], relationships=categories)
    v = editable_version(asc, a["id"])
    vm = META["version"]
    asc.patch(f"/v1/appStoreVersions/{v['id']}", "appStoreVersions", v["id"], {"copyright": vm["copyright"]})
    attrs = {"description": vm["description"], "keywords": vm["keywords"], "supportUrl": vm["supportUrl"],
             "marketingUrl": vm["marketingUrl"], "promotionalText": vm["promotionalText"]}
    # A first version has no "What's New"; the field only opens from 1.1 on.
    versions = asc.get(f"/v1/apps/{a['id']}/appStoreVersions", **{"filter[platform]": "IOS"})["data"]
    if len(versions) > 1:
        attrs["whatsNew"] = vm["whatsNew"]
    localization(asc, f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations", "appStoreVersionLocalizations",
                 {"appStoreVersion": rel("appStoreVersions", v["id"])}, attrs)
    print("metadata: subtitle, privacy URL, categories, description, keywords, URLs set")


def cmd_review(asc):
    a = app(asc)
    v = editable_version(asc, a["id"])
    r = META["review"]
    attrs = {k: r[k] for k in ("contactFirstName", "contactLastName", "contactEmail", "contactPhone",
                                "demoAccountRequired", "notes") if r.get(k) not in (None, "")}
    try:
        existing = asc.get(f"/v1/appStoreVersions/{v['id']}/appStoreReviewDetail")["data"]
    except RuntimeError:
        existing = None
    if existing:
        asc.patch(f"/v1/appStoreReviewDetails/{existing['id']}", "appStoreReviewDetails", existing["id"], attrs)
    else:
        asc.post("/v1/appStoreReviewDetails", "appStoreReviewDetails", attrs,
                 {"appStoreVersion": rel("appStoreVersions", v["id"])})
    print("review: contact and notes set")


def cmd_age_rating(asc):
    a = app(asc)
    info = editable_app_info(asc, a["id"])
    decl = asc.get(f"/v1/appInfos/{info['id']}/ageRatingDeclaration")["data"]
    wanted = META["ageRating"]
    # Only send attributes this API version knows about, so a renamed field
    # does not fail the whole declaration.
    known = set(decl["attributes"].keys())
    attrs = {k: v for k, v in wanted.items() if k in known}
    skipped = sorted(set(wanted) - known)
    asc.patch(f"/v1/ageRatingDeclarations/{decl['id']}", "ageRatingDeclarations", decl["id"], attrs)
    print(f"age rating: set {sorted(attrs)}" + (f"; not in this API: {skipped}" if skipped else ""))


def cmd_screenshots(asc):
    a = app(asc)
    v = editable_version(asc, a["id"])
    locs = asc.get(f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")["data"]
    loc = next(l for l in locs if l["attributes"]["locale"] == META["locale"])
    root = ROOT / "marketing" / "store"
    folders = sorted(p for p in root.iterdir() if p.is_dir() and list(p.glob("*.png")))
    if not folders:
        sys.exit(f"no screenshot folders in {root}")
    sets = asc.get(f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
    for folder in folders:
        display_type = folder.name
        files = sorted(folder.glob("*.png"))
        target = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == display_type), None)
        if target:
            for shot in asc.get(f"/v1/appScreenshotSets/{target['id']}/appScreenshots")["data"]:
                asc.delete(f"/v1/appScreenshots/{shot['id']}")
        else:
            target = asc.post("/v1/appScreenshotSets", "appScreenshotSets",
                              {"screenshotDisplayType": display_type},
                              {"appStoreVersionLocalization": rel("appStoreVersionLocalizations", loc["id"])})
        ids = []
        for f in files:
            ids.append(upload_asset(asc, "/v1/appScreenshots", "appScreenshots",
                                    {"appScreenshotSet": rel("appScreenshotSets", target["id"])}, f, "appScreenshots"))
            print(f"  {display_type}: uploaded {f.name}")
        asc.call("PATCH", f"/v1/appScreenshotSets/{target['id']}/relationships/appScreenshots",
                 json={"data": [{"type": "appScreenshots", "id": i} for i in ids]})
        print(f"screenshots: {len(ids)} in {display_type}")


def complete_screenshot(asc, path, type_):
    """True when a finished review screenshot exists. A reservation whose
    upload never completed is removed so it can be replaced."""
    try:
        shot = asc.get(path)["data"]
    except RuntimeError:
        return False
    if not shot:
        return False
    state = (shot["attributes"].get("assetDeliveryState") or {}).get("state")
    if state == "COMPLETE":
        return True
    try:
        asc.delete(f"/v1/{type_}/{shot['id']}")
    except RuntimeError:
        pass
    return False


def territories(asc):
    return [t["id"] for t in asc.get_all("/v1/territories", limit=200)]


def cmd_pricing(asc):
    a = app(asc)
    asc.patch(f"/v1/apps/{a['id']}", "apps", a["id"], {"contentRightsDeclaration": META["contentRights"]})
    print(f"  content rights: {META['contentRights']}")
    # A new app already has an empty price schedule, so look for actual prices on it.
    try:
        schedule = asc.get(f"/v1/apps/{a['id']}/appPriceSchedule")["data"]
        priced = bool(asc.get(f"/v1/appPriceSchedules/{schedule['id']}/manualPrices")["data"])
    except RuntimeError:
        priced = False
    if priced:
        print("  price schedule already set")
    else:
        points = asc.get_all(f"/v1/apps/{a['id']}/appPricePoints", **{"filter[territory]": "USA", "limit": 200})
        free = next(p for p in points if float(p["attributes"]["customerPrice"]) == 0)
        asc.call("POST", "/v1/appPriceSchedules", json={"data": {
            "type": "appPriceSchedules",
            "relationships": {
                "app": rel("apps", a["id"]),
                "baseTerritory": rel("territories", "USA"),
                "manualPrices": {"data": [{"type": "appPrices", "id": "${price1}"}]},
            }},
            "included": [{"type": "appPrices", "id": "${price1}",
                          "attributes": {"startDate": None},
                          "relationships": {"appPricePoint": rel("appPricePoints", free["id"])}}]})
        print("  price: free")
    try:
        asc.get(f"/v1/apps/{a['id']}/appAvailabilityV2")
        print("  availability already set")
    except RuntimeError:
        ids = territories(asc)
        asc.call("POST", "/v2/appAvailabilities", json={"data": {
            "type": "appAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "app": rel("apps", a["id"]),
                "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": f"${{t{i}}}"} for i in range(len(ids))]},
            }},
            "included": [{"type": "territoryAvailabilities", "id": f"${{t{i}}}",
                          "attributes": {"available": True},
                          "relationships": {"territory": rel("territories", t)}} for i, t in enumerate(ids)]})
        print(f"  availability: {len(ids)} territories")
    print("pricing: done")


def cmd_testflight(asc):
    a = app(asc)
    build = None
    for _ in range(60):
        builds = asc.get("/v1/builds", **{"filter[app]": a["id"], "sort": "-uploadedDate", "limit": 1})["data"]
        if builds and builds[0]["attributes"]["processingState"] == "VALID":
            build = builds[0]
            break
        state = builds[0]["attributes"]["processingState"] if builds else "no build yet"
        print(f"  waiting for the build to process ({state})")
        time.sleep(30)
    if not build:
        sys.exit("no processed build after 30 minutes")
    tf = META["testflight"]
    groups = asc.get(f"/v1/apps/{a['id']}/betaGroups")["data"]
    group = next((g for g in groups if g["attributes"]["isInternalGroup"]), None)
    if not group:
        group = asc.post("/v1/betaGroups", "betaGroups",
                         {"name": tf["groupName"], "isInternalGroup": True, "hasAccessToAllBuilds": True},
                         {"app": rel("apps", a["id"])})
    if not group["attributes"].get("hasAccessToAllBuilds"):
        asc.call("POST", f"/v1/betaGroups/{group['id']}/relationships/builds",
                 json={"data": [{"type": "builds", "id": build["id"]}]})
    # The account holder tests first. Internal testers are App Store Connect
    # users; adding the address to the internal group enables them.
    testers = {t["attributes"]["email"]: t for t in asc.get(f"/v1/betaGroups/{group['id']}/betaTesters")["data"]}
    for user in asc.get("/v1/users")["data"]:
        email = user["attributes"]["username"]
        if email in testers:
            continue
        try:
            asc.post("/v1/betaTesters", "betaTesters",
                     {"email": email, "firstName": user["attributes"].get("firstName", ""),
                      "lastName": user["attributes"].get("lastName", "")},
                     {"betaGroups": {"data": [{"type": "betaGroups", "id": group["id"]}]}})
            print(f"  tester added: {email}")
        except RuntimeError as e:
            print(f"  could not add {email} as a tester: {str(e)[:200]}")
    locs = asc.get(f"/v1/builds/{build['id']}/betaBuildLocalizations")["data"]
    if locs:
        asc.patch(f"/v1/betaBuildLocalizations/{locs[0]['id']}", "betaBuildLocalizations", locs[0]["id"],
                  {"whatsNew": tf["whatsNew"]})
    else:
        asc.post("/v1/betaBuildLocalizations", "betaBuildLocalizations",
                 {"locale": META["locale"], "whatsNew": tf["whatsNew"]}, {"build": rel("builds", build["id"])})
    print(f"testflight: build {build['attributes']['version']} in group {group['attributes']['name']}")


def wait_for_build(asc, app_id, number=None):
    """The newest VALID build, or the one numbered `number`, once processed."""
    for _ in range(80):
        builds = asc.get("/v1/builds", **{"filter[app]": app_id, "sort": "-uploadedDate", "limit": 10})["data"]
        wanted = [b for b in builds if number is None or b["attributes"]["version"] == str(number)]
        if wanted and wanted[0]["attributes"]["processingState"] == "VALID":
            return wanted[0]
        state = wanted[0]["attributes"]["processingState"] if wanted else "not uploaded yet"
        print(f"  waiting for build {number or 'newest'} to process ({state})")
        time.sleep(30)
    sys.exit("the build did not finish processing in 40 minutes")


def cmd_submit(asc):
    a = app(asc)
    build = wait_for_build(asc, a["id"], os.environ.get("ASC_BUILD"))
    number = build["attributes"]["version"]
    version = editable_version(asc, a["id"])
    vid = version["id"]
    print(f"  version {version['attributes']['versionString']} is {version['attributes']['appStoreState']}; build {number} is processed")

    # A submission already in the queue is withdrawn; its items come along.
    # Withdrawal is asynchronous, and the version cannot take a new build
    # until it has gone through.
    carried, withdrawn, unsent = [], [], None
    open_states = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"}
    subs = asc.get(f"/v1/apps/{a['id']}/reviewSubmissions", **{"filter[platform]": "IOS"})["data"]
    subs.sort(key=lambda s: s["attributes"].get("submittedDate") or "", reverse=True)
    # With nothing in the queue, the newest submission of any state still
    # names the purchase items that have to ride along again.
    recent = subs[:1]
    for sub in [s for s in subs if s["attributes"]["state"] in open_states] or recent:
        items = asc.get(f"/v1/reviewSubmissions/{sub['id']}/items",
                        include="appStoreVersion,subscriptionVersion,subscriptionGroupVersion,inAppPurchaseVersion")["data"]
        for item in items:
            for kind, link in item.get("relationships", {}).items():
                if link.get("data") and kind != "appStoreVersion":
                    entry = (kind, link["data"]["type"], link["data"]["id"])
                    if entry not in carried:
                        carried.append(entry)
        if sub["attributes"]["state"] == "READY_FOR_REVIEW":
            # The API cannot delete a submission that was never sent, so it is reused.
            unsent = sub
            print(f"  reusing the unsent submission {sub['id']}")
        elif sub["attributes"]["state"] in open_states:
            asc.patch(f"/v1/reviewSubmissions/{sub['id']}", "reviewSubmissions", sub["id"], {"canceled": True})
            print(f"  withdrew submission {sub['id']} ({sub['attributes']['state']})")
            withdrawn.append(sub["id"])
        elif sub["attributes"]["state"] == "CANCELING":
            withdrawn.append(sub["id"])
    for sid in withdrawn:
        for _ in range(40):
            try:
                state = asc.get(f"/v1/reviewSubmissions/{sid}")["data"]["attributes"]["state"]
            except RuntimeError as e:
                # A withdrawn submission can disappear outright; that is done too.
                if "404" in str(e):
                    break
                raise
            if state != "CANCELING":
                break
            print("  waiting for the withdrawal to go through")
            time.sleep(15)

    for attempt in range(20):
        try:
            asc.call("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build",
                     json={"data": {"type": "builds", "id": build["id"]}})
            break
        except RuntimeError as e:
            if "INVALID_STATE" not in str(e) or attempt == 19:
                raise
            print("  the version is not ready for a new build yet; waiting")
            time.sleep(15)
    print(f"  build {number} attached to version {version['attributes']['versionString']}")

    submission = unsent or asc.post("/v1/reviewSubmissions", "reviewSubmissions", {"platform": "IOS"}, {"app": rel("apps", a["id"])})
    present = set()
    if unsent:
        for item in asc.get(f"/v1/reviewSubmissions/{submission['id']}/items")["data"]:
            for kind, link in item.get("relationships", {}).items():
                if link.get("data"):
                    present.add((kind, link["data"]["type"], link["data"]["id"]))
    items = [("appStoreVersion", "appStoreVersions", vid)] + carried
    for kind, type_, id_ in items:
        if (kind, type_, id_) in present:
            continue
        asc.post("/v1/reviewSubmissionItems", "reviewSubmissionItems", None,
                 {"reviewSubmission": rel("reviewSubmissions", submission["id"]), kind: rel(type_, id_)})
    submitted = asc.patch(f"/v1/reviewSubmissions/{submission['id']}", "reviewSubmissions", submission["id"], {"submitted": True})
    state = submitted["attributes"]["state"]
    print(f"submit: build {number} submitted for review ({state}, {len(items)} items)")

    folder = ROOT / "build" / "releases" / f"{version['attributes']['versionString']}-{number}"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "app-store-build.json").write_text(json.dumps(build, indent=2))
    (folder / "submission.json").write_text(json.dumps(submitted, indent=2))
    (folder / "review-items.json").write_text(json.dumps(asc.get(
        f"/v1/reviewSubmissions/{submission['id']}/items",
        include="appStoreVersion,subscriptionVersion,subscriptionGroupVersion,inAppPurchaseVersion"), indent=2))
    (folder / "release-status.json").write_text(json.dumps({
        "version": version["attributes"]["versionString"], "build": number, "status": state,
        "submittedDate": submitted["attributes"].get("submittedDate"), "submissionId": submission["id"],
        "buildId": build["id"], "reviewItems": len(items),
    }, indent=2))
    print(f"  release record: {folder.relative_to(ROOT)}")


COMMANDS = {
    "info": cmd_info, "metadata": cmd_metadata, "review": cmd_review, "age-rating": cmd_age_rating,
    "screenshots": cmd_screenshots, "pricing": cmd_pricing, "testflight": cmd_testflight, "submit": cmd_submit,
}


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--key-id", default=os.environ.get("ASC_KEY_ID"))
    p.add_argument("--issuer-id", default=os.environ.get("ASC_ISSUER_ID"))
    p.add_argument("--key-file", default=os.path.expanduser(os.environ.get("ASC_KEY_FILE", "")))
    p.add_argument("command", choices=list(COMMANDS) + ["all"])
    args = p.parse_args()
    if not (args.key_id and args.issuer_id and args.key_file):
        sys.exit("need --key-id, --issuer-id, --key-file (or ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE)")
    asc = ASC(args.key_id, args.issuer_id, args.key_file)
    steps = ["metadata", "review", "age-rating", "screenshots", "pricing"] if args.command == "all" else [args.command]
    for step in steps:
        print(f"== {step}")
        COMMANDS[step](asc)


if __name__ == "__main__":
    main()
