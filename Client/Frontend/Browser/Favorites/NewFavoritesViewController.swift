// Copyright 2020 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit
import Data
import Shared
import CoreData

private let log = Logger.browserLogger

private class FavoritesHeaderView: UICollectionReusableView {
    let label = UILabel().then {
        $0.text = "Favorites"
        $0.font = .systemFont(ofSize: 18, weight: .semibold)
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(12)
            $0.trailing.lessThanOrEqualToSuperview().inset(12)
            $0.centerY.equalToSuperview()
        }
    }
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }
//    func applyTheme(_ theme: Theme) {
//        label.textColor = theme.
//    }
}

class NewFavoritesViewController: UIViewController, Themeable {
    
    var action: (Bookmark, BookmarksAction) -> Void
    
    private let frc = Bookmark.frc(forFavorites: true, parentFolder: nil)
    
    private let layout = UICollectionViewFlowLayout().then {
        $0.sectionInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        $0.minimumInteritemSpacing = 0
        $0.minimumLineSpacing = 8
    }
    private let collectionView: UICollectionView
    private let backgroundView = UIVisualEffectView()
    
    init(action: @escaping (Bookmark, BookmarksAction) -> Void) {
        self.action = action
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(nibName: nil, bundle: nil)
        
        collectionView.register(FavoriteCell.self, forCellWithReuseIdentifier: FavoriteCell.identifier)
        collectionView.register(FavoritesHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = UIEdgeInsets(top: 24, left: 0, bottom: 0, right: 0)
        
        frc.delegate = self
        
        KeyboardHelper.defaultHelper.addDelegate(self)
        
        do {
            try frc.performFetch()
        } catch {
            log.error("Favorites fetch error: \(String(describing: error))")
        }
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.backgroundColor = .clear
        
        view.addSubview(backgroundView)
        view.addSubview(collectionView)
        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        calculateAppropriateGrid()
    }
    
    func applyTheme(_ theme: Theme) {
        let blurStyle: UIBlurEffect.Style = theme.isDark ? .dark : .extraLight
        backgroundView.effect = UIBlurEffect(style: blurStyle)
        backgroundView.contentView.backgroundColor = theme.colors.home.withAlphaComponent(0.5)
        collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        collectionView.contentInset = collectionView.contentInset.with {
            $0.left = self.view.readableContentGuide.layoutFrame.minX
            $0.right = self.view.readableContentGuide.layoutFrame.minX
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        calculateAppropriateGrid()
        
        if let state = KeyboardHelper.defaultHelper.currentState {
            updateKeyboardInset(state, animated: false)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        calculateAppropriateGrid()
    }
    
    private func calculateAppropriateGrid() {
        let width = collectionView.bounds.width -
            (layout.sectionInset.left + layout.sectionInset.right) -
            (collectionView.contentInset.left + collectionView.contentInset.right)
        // Want to fit _at least_ 4 on all devices, but on larger devices
        // allowing the cells to be a bit bigger
        let minimumNumberOfColumns = 4
        let minWidth = floor(width / CGFloat(minimumNumberOfColumns))
        // Default width should be 82, but may get smaller or bigger
        var itemSize = CGSize(width: 82, height: FavoriteCell.height(forWidth: 82))
        if minWidth < 82 {
            itemSize = CGSize(width: floor(width / 4.0), height: FavoriteCell.height(forWidth: floor(width / 4.0)))
        } else if traitCollection.horizontalSizeClass == .regular {
            // On iPad's or Max/Plus phones allow the icons to get bigger to an
            // extent
            if width / CGFloat(minimumNumberOfColumns) > 100.0 {
                itemSize = CGSize(width: 100, height: FavoriteCell.height(forWidth: 100))
            }
        }
        layout.itemSize = itemSize
        layout.invalidateLayout()
    }
}

// MARK: - KeyboardHelperDelegate
extension NewFavoritesViewController: KeyboardHelperDelegate {
    func updateKeyboardInset(_ state: KeyboardState, animated: Bool = true) {
        let keyboardHeight = state.intersectionHeightForView(self.view) - view.safeAreaInsets.bottom
        UIView.animate(withDuration: animated ? state.animationDuration : 0.0, animations: {
            if animated {
                UIView.setAnimationCurve(state.animationCurve)
            }
            self.collectionView.contentInset = self.collectionView.contentInset.with {
                $0.bottom = keyboardHeight
            }
            self.collectionView.scrollIndicatorInsets = self.collectionView.scrollIndicatorInsets.with {
                $0.bottom = keyboardHeight
            }
        })
    }
    
    func keyboardHelper(_ keyboardHelper: KeyboardHelper, keyboardWillShowWithState state: KeyboardState) {
        updateKeyboardInset(state)
    }
    
    func keyboardHelper(_ keyboardHelper: KeyboardHelper, keyboardDidShowWithState state: KeyboardState) {
    }
    
    func keyboardHelper(_ keyboardHelper: KeyboardHelper, keyboardWillHideWithState state: KeyboardState) {
        updateKeyboardInset(state)
    }
}

// MARK: - UICollectionViewDataSource & UICollectionViewDelegateFlowLayout
extension NewFavoritesViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return frc.fetchedObjects?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let bookmark = frc.fetchedObjects?[safe: indexPath.item] else {
            return
        }
        action(bookmark, .opened())
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath)
//            view.layoutMargins = UIEdgeInsets(top: 0, left: self.view.readableContentGuide.layoutFrame.minX, bottom: 0, right: self.view.readableContentGuide.layoutFrame.minX)
            return view
        }
        return UICollectionReusableView()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // swiftlint:disable:next force_cast
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FavoriteCell.identifier, for: indexPath) as! FavoriteCell
        let fav = frc.object(at: IndexPath(item: indexPath.item, section: 0))
        cell.textLabel.text = fav.displayTitle ?? fav.url
        cell.textLabel.appearanceTextColor = nil
        cell.imageView.setIconMO(nil, forURL: URL(string: fav.url ?? ""), scaledDefaultIconSize: CGSize(width: 40, height: 40), completed: { (color, url) in
            if fav.url == url?.absoluteString {
                cell.imageView.backgroundColor = color
            }
        })
        cell.accessibilityLabel = cell.textLabel.text
        cell.longPressHandler = { [weak self] cell in
            guard let self = self else { return }
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
            let edit = UIAlertAction(title: Strings.editBookmark, style: .default) { (action) in
                self.action(fav, .edited)
            }
            let delete = UIAlertAction(title: Strings.removeFavorite, style: .destructive) { (action) in
                fav.delete()
            }
            
            alert.addAction(edit)
            alert.addAction(delete)
            
            alert.popoverPresentationController?.sourceView = cell
            alert.popoverPresentationController?.permittedArrowDirections = [.down, .up]
            alert.addAction(UIAlertAction(title: Strings.close, style: .cancel, handler: nil))
            
            UIImpactFeedbackGenerator(style: .medium).bzzt()
            self.present(alert, animated: true)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 32)
    }
    
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
////        return UIEdgeInsets(top: 12, left: self.view.readableContentGuide.layoutFrame.minX, bottom: 12, right: self.view.readableContentGuide.layoutFrame.minX)
//    }
    
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let favourite = frc.fetchedObjects?[indexPath.item] else { return nil }
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ -> UIMenu? in
            let openInNewTab = UIAction(title: Strings.openNewTabButtonTitle, image: nil, identifier: nil, discoverabilityTitle: nil) { _ in
                self.action(favourite, .opened(inNewTab: true, switchingToPrivateMode: false))
            }
            let edit = UIAction(title: Strings.editBookmark, image: nil, identifier: nil, discoverabilityTitle: nil) { _ in
                self.action(favourite, .edited)
            }
            let delete = UIAction(title: Strings.removeFavorite, image: nil, identifier: nil, discoverabilityTitle: nil, attributes: .destructive) { _ in
                favourite.delete()
            }
            
            var urlChildren: [UIAction] = [openInNewTab]
            if !PrivateBrowsingManager.shared.isPrivateBrowsing {
                let openInNewPrivateTab = UIAction(title: Strings.openNewPrivateTabButtonTitle, image: nil, identifier: nil, discoverabilityTitle: nil) { _ in
                    self.action(favourite, .opened(inNewTab: true, switchingToPrivateMode: true))
                }
                urlChildren.append(openInNewPrivateTab)
            }
            
            let urlMenu = UIMenu(title: "", options: .displayInline, children: urlChildren)
            let favMenu = UIMenu(title: "", options: .displayInline, children: [edit, delete])
            return UIMenu(title: favourite.title ?? favourite.url ?? "", identifier: nil, children: [urlMenu, favMenu])
        }
    }
    
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath,
            let cell = collectionView.cellForItem(at: indexPath) as? FavoriteCell else {
                return nil
        }
        return UITargetedPreview(view: cell.imageView)
    }
    
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath,
            let cell = collectionView.cellForItem(at: indexPath) as? FavoriteCell else {
                return nil
        }
        return UITargetedPreview(view: cell.imageView)
    }
}

// MARK: - NSFetchedResultsControllerDelegate
extension NewFavoritesViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        collectionView.reloadData()
    }
}