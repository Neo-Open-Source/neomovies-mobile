export type Dictionary = {
  appName: string;
  tabs: {
    home: string;
    search: string;
    favorites: string;
    profile: string;
    details: string;
  };
  favorites: {
    empty: string;
    authRequired: string;
  };
  profile: {
    authTitle: string;
    authDescription: string;
    authAction: string;
    authLoading: string;
    loadingProfile: string;
    settings: string;
    about: string;
    updates?: string;
    logout: string;
  };
  about: {
    appDescription: string;
    checkUpdates: string;
    checkUpdatesDesc: string;
    credits: string;
    creditsDesc: string;
    changelog: string;
    changelogDesc: string;
    version: string;
    branch: string;
    build: string;
  };
  media: {
    movie: string;
    tv: string;
    watch: string;
    download: string;
  };
  home: {
    continueWatching: string;
    popular: string;
    topFilms: string;
    topSeries: string;
    watchNow: string;
    loading: string;
    loadError: string;
  };
  search: {
    title: string;
    placeholder: string;
    loadError: string;
    recentTitle: string;
    emptyState: string;
  };
  watchSelector: {
    title: string;
    seasons: string;
    episodes: string;
    primary: string;
    missingPayload: string;
  };
  settings: {
    title: string;
    common: string;
    source: string;
    language: string;
    appearance: string;
    darkTheme: string;
    storage: string;
    clearCache: string;
    clearCacheDesc: string;
    defaultSource: string;
    sourceDefaultTitle: string;
    sourceDefaultDesc: string;
    sourceAlternativeTitle: string;
    sourceAlternativeDesc: string;
  };
};

export type Locale = 'en' | 'ru' | 'uk' | 'be' | 'ro';
