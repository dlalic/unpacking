export const flags = ({ env }) => {
  // Called before our Elm application starts
  return {
    height: window.innerHeight,
    width: window.innerWidth,
    user: JSON.parse(window.localStorage.user || null)
  }
}

export const onReady = ({ env, app }) => {
  // Called after our Elm application starts
  if (app.ports && app.ports.sendToLocalStorage) {
    app.ports.sendToLocalStorage.subscribe(({ key, value }) => {
      window.localStorage[key] = JSON.stringify(value)
    })
  }
}
