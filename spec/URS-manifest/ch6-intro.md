The **Mobile Application** is a single iOS and Android application distributed through the public app stores without sponsor branding. It supports two operating modes.

**Personal use mode** requires no account and stores all data locally on the device, supporting private health tracking by an individual **User** outside of any clinical-trial context.

**Linked use mode** connects the application to a **Sponsor Portal** deployment and operates as the electronic source (eSource) for the clinical trial. The linked individual is a **Participant**. A single installation may be linked to multiple studies simultaneously; each link is scoped to its own sponsor, and data captured under one link is never exposed to another. Personal-use data is carried into linked mode only with the **User**'s explicit consent at the time of linking.

In both modes the application is offline-first: entry creation, edit, and history review work without network connectivity, and linked installations queue unsynchronized entries locally for automatic transmission when connectivity returns.

The base application contains no sponsor-identifying information — no sponsor name, logo, URL, or branding asset appears in the installed app until a **Participant** has completed an authenticated linking flow. This protects sponsor clinical-trial activity from inadvertent disclosure and prevents the application from being reverse-engineered to enumerate which studies use the platform.
