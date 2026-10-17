# Warfront Mandate website deployment

The existing game repository now has a buildless landing page in `website/`. This is the public development website, not a Godot web export, multiplayer server, or account backend.

## Cloudflare Pages settings

- Repository: `pimpurcity-eng/command-of-nations-game`
- Project name: `warfront-mandate`
- Production branch for the prepared website: `chatgpt/warfront-mandate-hosting`
- Framework preset: None
- Build command: `exit 0`
- Build output directory: `website`
- Root directory: leave empty (repository root)
- Environment variables: none

Create a Pages application through Workers & Pages. Connect GitHub and grant Cloudflare access only to this repository. Select the branch and settings above; do not deploy the repository root.

First open the returned `pages.dev` address. Verify the title, navigation, mobile scrolling and GitHub link. The page must clearly say multiplayer is not open yet. Browser visual QA has not been run in this preparation environment.

After the preview works, open the Pages project's Custom domains section and add `warfrontmandate.com`. Use Cloudflare's offered DNS configuration. Add `www.warfrontmandate.com` separately if desired. Verify HTTPS and both intended addresses. Do not change email records.

No Cloudflare deployment or DNS changes were made by preparing this branch. No paid game server was provisioned.

## Persistent game hosting (next implementation phase)

Use the existing Godot project, preserving its campaign and assets. Before buying server capacity, inspect the simulation's current state and implement an authoritative server: validated orders, continuous simulation without rendering, reconnect handling, persistent saves and server restart recovery. Account authentication, confirmed email and password resets need a separate tested backend and email provider. Load-test representative matches before promising capacity or inviting all testers.

The website can be deployed independently while multiplayer work continues. Keep production save data separate from development, use backups and confirm restore behavior before public testing.

## Reference

https://developers.cloudflare.com/pages/framework-guides/deploy-anything/
https://developers.cloudflare.com/pages/get-started/git-integration/
