Rx = require 'rx-lite'
_ = require 'underscore'
QuerySubscriptionPool = require '../flux/models/query-subscription-pool'
AccountStore = require '../flux/stores/account-store'
DatabaseStore = require '../flux/stores/database-store'

AccountOperators = {}

AccountObservables = {}

CategoryOperators =
  sort: ->
    obs = @.map (categories) ->
      return categories.sort (catA, catB) ->
        nameA = catA.displayName
        nameB = catB.displayName

        # Categories that begin with [, like [Mailbox]/For Later
        # should appear at the bottom, because they're likely autogenerated.
        nameA = "ZZZ"+nameA if nameA[0] is '['
        nameB = "ZZZ"+nameB if nameB[0] is '['

        nameA.localeCompare(nameB)
    _.extend(obs, CategoryOperators)

  categoryFilter: (filter) ->
    obs = @.map (categories) ->
      return categories.filter filter
    _.extend(obs, CategoryOperators)

CategoryObservables =

  forAllAccounts: =>
    observable = Rx.Observable.fromStore(AccountStore).flatMapLatest ->
      observables = AccountStore.accounts().map (account) ->
        categoryClass = account.categoryClass()
        Rx.Observable.fromQuery(DatabaseStore.findAll(categoryClass))
      Rx.Observable.concat(observables)
    _.extend(observable, CategoryOperators)
    observable

  forAccount: (account) =>
    if account
      categoryClass = account.categoryClass()
      observable = Rx.Observable.fromQuery(DatabaseStore.findAll(categoryClass)
        .where(categoryClass.attributes.accountId.equal(account.id)))
    else
      observable = CategoryObservables.forAllAccounts()
    _.extend(observable, CategoryOperators)
    observable

  standardForAccount: (account) =>
    observable = Rx.Observable.fromConfig('core.workspace.showImportant')
      .flatMapLatest (showImportant) =>
        accountObservable = CategoryObservables.forAccount(account)
        return accountObservable.categoryFilter (cat) ->
          if showImportant is true
            cat.isStandardCategory()
          else
            cat.isStandardCategory() and cat.name isnt 'important'
    _.extend(observable, CategoryOperators)
    observable

module.exports =
  Categories: CategoryObservables
  Accounts: AccountObservables

# Attach a few global helpers
#
Rx.Observable::last = ->
  @takeLast(1).toArray()[0]

Rx.Observable.fromStore = (store) =>
  return Rx.Observable.create (observer) =>
    unsubscribe = store.listen =>
      observer.onNext(store)
    observer.onNext(store)
    return Rx.Disposable.create(unsubscribe)

Rx.Observable.fromConfig = (configKey) =>
  return Rx.Observable.create (observer) =>
    disposable = NylasEnv.config.observe configKey, =>
      observer.onNext(NylasEnv.config.get(configKey))
    observer.onNext(NylasEnv.config.get(configKey))
    return Rx.Disposable.create(disposable.dispose)

Rx.Observable.fromAction = (action) =>
  return Rx.Observable.create (observer) =>
    unsubscribe = action.listen (args...) =>
      observer.onNext(args...)
    return Rx.Disposable.create(unsubscribe)

Rx.Observable.fromQuery = (query) =>
  return Rx.Observable.create (observer) =>
    unsubscribe = QuerySubscriptionPool.add query, (result) =>
      observer.onNext(result)
    return Rx.Disposable.create(unsubscribe)

Rx.Observable.fromPrivateQuerySubscription = (name, subscription) =>
  return Rx.Observable.create (observer) =>
    unsubscribe = QuerySubscriptionPool.addPrivateSubscription name, subscription, (result) =>
      observer.onNext(result)
    return Rx.Disposable.create(unsubscribe)