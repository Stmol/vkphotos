//
//  AlbumsTableController.swift
//  VKPhotos
//
//  Created by Yury Smidovich on 01/08/2018.
//  Copyright © 2018 Yury Smidovich. All rights reserved.
//

import UIKit

class VKAlbumsTableController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    let cellId = "vkAlbumTableCell"
    let limitPerPage = 50

    var onVKAlbumSelected: ((VKAlbum) -> Void)?
    var excludedVKAlbumIds = [Int]()
    var isSystemAlbumsExcluded = false

    private var albumsManager: VKAlbumManager!
    private var isLoadingNextPage: Bool = false
    private var albums = [VKAlbum]() {
        didSet {
            if !excludedVKAlbumIds.isEmpty {
                albums = albums.filter({ !excludedVKAlbumIds.contains($0.id) })
            }
        }
    }
    private var selectedVKAlbum: VKAlbum? {
        if let indexPath = tableView.indexPathForSelectedRow {
            return albums[indexPath.row]
        }

        return nil
    }

    @IBOutlet weak var tableTopConstraint: NSLayoutConstraint! {
        didSet {
            // 0.5 значение не хочет выставляться в редакторе сториборда
            tableTopConstraint.constant = 0.5
        }
    }
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.delegate = self
            tableView.dataSource = self
            tableView.tableFooterView = UIView()
            tableView.rowHeight = 74.0
            tableView.tableFooterView = footerView

            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(onRefresh), for: .valueChanged)

            refreshControl.isUserInteractionEnabled = false
            refreshControl.layer.zPosition = -1
            refreshControl.backgroundColor = .white

            tableView.refreshControl = refreshControl
        }
    }

    private lazy var albumsCountLabel: UILabel = {
        let label = UILabel()
        label.text = "Нет доступных альбомов"
        label.textColor = UIColor(hex: "71757A")
        label.textAlignment = .center
        label.isHidden = true

        return label
    }()

    private lazy var albumsLoaderIndicator: UIActivityIndicatorView = {
        let loader = UIActivityIndicatorView()
        loader.startAnimating()
        loader.activityIndicatorViewStyle = .gray

        return loader
    }()

    private lazy var footerView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 70))

        view.addSubview(albumsCountLabel)
        albumsCountLabel.anchorCenterSuperview()

        view.addSubview(albumsLoaderIndicator)
        albumsLoaderIndicator.anchorCenterSuperview()

        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        startLoading()

        albumsManager = VKAlbumManager()
        albumsManager.getAlbums(count: limitPerPage, !isSystemAlbumsExcluded)
            .then { [weak self] vkAlbums in
                self?.albums = vkAlbums
                self?.tableView.reloadData()
            }
            .catch { [weak self] _ in
                self?.showErrorNotification(Messages.Errors.failToFetchNewData)
            }
            .always(in: .main) { [weak self] in
                self?.stopLoading()
            }
    }

    @IBAction func cancelBarButtonTap(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }

    @IBAction func doneBarButtonTap(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: { [weak self] in
            if let vkAlbum = self?.selectedVKAlbum {
                self?.onVKAlbumSelected?(vkAlbum)
            }
        })
    }

    @objc func onRefresh(_ refreshControl: UIRefreshControl) {
        albumsManager.getAlbums(count: limitPerPage, !isSystemAlbumsExcluded)
            .then { [weak self] vkAlbums in
                self?.albums = vkAlbums
                self?.tableView.reloadData()
            }
            .catch { [weak self] _ in
                self?.showErrorNotification(Messages.Errors.failToFetchNewData)
            }
            .always(in: .main) { refreshControl.endRefreshing() }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return albums.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! VKAlbumsTableCell
        cell.setup(albums[indexPath.row])
        cell.accessoryType = albums[indexPath.row] == selectedVKAlbum ? .checkmark : .none

        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard
            albumsManager.vkAlbums.count < albumsManager.totalCount,
            scrollView.contentSize.height > scrollView.frame.size.height
            else { return }

        let bottomEdge: CGFloat = scrollView.contentOffset.y + scrollView.frame.size.height
        guard !isLoadingNextPage && bottomEdge >= (scrollView.contentSize.height - 50) else { return }

        isLoadingNextPage = true
        startLoading()

        albumsManager.getNextAlbums(count: limitPerPage, !isSystemAlbumsExcluded)
            .then { [weak self] vkAlbums in
                guard let this = self else { return }

                let diffCount = this.albums.count..<this.albums.count + vkAlbums.count
                this.albums += vkAlbums

                let indexPaths = diffCount.map({ index -> IndexPath in
                    return IndexPath(row: index, section: 0)
                })

                this.tableView.insertRows(at: indexPaths, with: .none)
            }
            .catch { [weak self] _ in
                // TODO: Ошибка отображается коряво
                self?.showErrorNotification(Messages.Errors.failToFetchNewData)
            }
            .always(in: .main) { [weak self] in
                self?.stopLoading()

                // TODO: При ошибке чтобы не было спама нотификацией отложим переключение флага
                Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                    self?.isLoadingNextPage = false
                }
            }
    }

    private func stopLoading() {
        if albums.count > 0 {
            tableView.tableFooterView = nil
            return
        }

        albumsLoaderIndicator.isHidden = true
        albumsCountLabel.isHidden = false
    }

    private func startLoading() {
        albumsCountLabel.isHidden = true
        albumsLoaderIndicator.isHidden = false
        tableView.tableFooterView = footerView
    }
}
