# CopyM8 ♾️

CopyM8 is a fast, native clipboard manager that securely stores and synchronizes your copy history across devices.

## Repository Structure
This repository utilizes a monorepo architecture to house the cross-platform ecosystem for CopyM8:

* **`core/`**: Contains the source of truth for the project, including design principles, architecture documentation, and cloud-sync JSON schemas. 
* **`platforms/`**: Contains the completely isolated, native applications for each operating system (e.g., macOS, Android).

> *Note: CopyM8 strictly avoids non-native frameworks (like Electron or React Native) because clipboard monitoring and keyboard interception require deep, hyper-specific OS-level integrations.*

---

*See the individual platform directories for platform-specific build instructions and feature lists.*
