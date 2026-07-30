# Contributing

Use [GitHub Desktop](https://desktop.github.com/) for clone, commit, push, and pull requests. The only command-line step you need for this project is `make.bat`, and that can be double clicked on instead (see [SETUP.md](SETUP.md)).

## 1. GitHub account and access

1. Create a [GitHub](https://github.com/signup) account if you do not have one.
2. Accept the SquareDoom collaborator invite (email or GitHub notifications).
3. Confirm you can open [https://github.com/Kweepa/SquareDoom](https://github.com/Kweepa/SquareDoom).

## 2. Install GitHub Desktop

1. Download and install [GitHub Desktop](https://desktop.github.com/).
2. Sign in with your GitHub account when prompted.

## 3. Clone the repo

1. In GitHub Desktop: **File → Clone repository…**
2. On the **GitHub.com** tab, select **Kweepa/SquareDoom**.
3. Choose a local folder and click **Clone**.

## 4. Tooling

Follow [SETUP.md](SETUP.md): install Node, Python, ACME, and VICE; copy and edit `setup-env.bat` if needed; confirm `make.bat` builds and runs.

## 5. Day-to-day workflow

You are going to use a branch (a light copy of the repository with only your changes) and a pull request (a request for me to pull the changes into the main branch).

1. In GitHub Desktop, make sure **Current branch** is `main`.
2. **Fetch origin** / **Pull origin** so you are up to date.
3. **Branch → New branch…**, name it for your change (for example `fix-door-sounds`), and create it from `main`.
4. Make your edits in the project folder.
5. Run `make.bat` and check that it still builds.
6. In GitHub Desktop, review the changed files, write a short summary, and click **Commit to [your branch]**.
7. Click **Publish branch** (first time) or **Push origin**.
8. Click **Create pull request** (or **Branch → Create pull request…**). The browser opens so you can finish the PR title and description on GitHub.

After I have reviewed the pull request and merged it:

1. In GitHub Desktop, switch **Current branch** back to `main`.
2. **Pull origin** to get the merged changes.

## Tips

- Run `make.bat` before pushing when you touch game code or assets and check it out in VICE (or on hardware!).
- Keep `setup-env.bat` local (it is gitignored).
- Do not push straight to `main` unless I ask you to; use a branch and a pull request.
- If you make a mistake, it is correctable, just let me know!