//
//  ViewController.swift
//  TMDB Reloaded
//
//  Created by Miguel Duran on 1/4/19.
//  Copyright © 2018 Miguel Duran. All rights reserved.
//

import UIKit

class MoviesViewController: UIViewController, Networked, MovieDetailsCoordinated, Stateful {
    weak var movieDetailsCoordinator: MovieDetailsFlowCoordinator?

    var stateController: StateController?
    var networkController: NetworkController?
    var dataSource: MoviesCollectionViewDataSource?
    var isScrollToFetch = true
    var selectedMovie: Movie?
    
    @IBOutlet weak var collectionView: UICollectionView!

}

// MARK: -
extension MoviesViewController {
    func setUpView() {
        collectionView.registerNib(forCellClass: MovieCollectionViewCell.self)
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.searchController = UISearchController(searchResultsController: FavoritesViewController())
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        updateDataSource([Movie]())
    }
    
    func fetchMovies() {
        networkController?.fetchList(for: TMDBEndpoint.popularMoviesURL) { [weak self] (result: Result<List<Movie>>) in
            (try? result.get()).map {
                self?.addMoviesToDataSource($0.results)
            }
        }
    }
}

// MARK: - CollectionView
extension MoviesViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        stateController?.delegates.remove(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stateController?.delegates.add(self)
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        movieDetailsCoordinator?.configure(viewController: segue.destination)
        selectedMovie.map { segue.forward(movie: $0)}
    }
}

// MARK: - StatefulDelegate
extension MoviesViewController: StatefulDelegate {
    func moviesChanged() {
        collectionView.reloadData()
    }
}

// MARK: - DataSource
extension MoviesViewController {
    func updateDataSource(_ movies: [Movie]) {
        dataSource = MoviesCollectionViewDataSource(movies: movies)
        collectionView.dataSource = dataSource
        collectionView.reloadData()
    }
    
    func addMoviesToDataSource(_ movies: [Movie]) {
        isScrollToFetch = movies.count > 0 ? true : false
        dataSource?.addMovies(movies)
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
}

// MARK: - UICollectionViewDelegate
extension MoviesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        guard let dataSource = dataSource, let movieCell = cell as? MovieCollectionViewCell, let state = stateController else { return }
        movieCell.delegate = self
        
        let movie = dataSource.movie(at: indexPath.row)
        let isFavorite = state.isMovieSaved(movie)
        dataSource.setFavorite(at: indexPath.row, isFavorite: isFavorite)
        movieCell.isFavorite = isFavorite
        
        networkController?.fecthImage(url: TMDBEndpoint.imageRootURL, imagePath: movie.posterPath, withCompletion: { result in
            (try? result.get()).map { image in
                DispatchQueue.main.async {
                    movieCell.posterImage = image
                }
            }
        })
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedMovie = dataSource?.movie(at: indexPath.row)
        movieDetailsCoordinator?.moviesViewControllerDidSelectMovieDetails(self)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension MoviesViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellHeight: CGFloat = 234, marginSpace: CGFloat = 12
        return CGSize(width: (collectionView.frame.width / 2) - marginSpace, height: cellHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let margin: CGFloat = 8
        return UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
    }
}

// MARK: -
extension MoviesViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let bottomEgde = (scrollView.contentOffset.y + scrollView.frame.height).rounded()
        let contentHeight = scrollView.contentSize.height
        if bottomEgde >= contentHeight && isScrollToFetch {
            isScrollToFetch = false
            fetchMovies()
        }
    }
}

// MARK: - MovieCollectionViewCellDelegate
extension MoviesViewController: MovieCollectionViewCellDelegate {
    func movieCell(_ cell: MovieCollectionViewCell) {
        guard let dataSource = dataSource, let index = collectionView.indexPath(for: cell)?.row else {
            return
        }
        dataSource.toggleFavorite(at: index)
        let movie = dataSource.movie(at: index)
        if movie.isFavorite {
            stateController?.addMovie(movie)
        } else {
            stateController?.removeMovie(movie)
        }
        collectionView.performBatchUpdates({
            cell.viewModel = MovieCollectionViewCell.ViewModel(movie: movie, posterImage: cell.posterImage)
        }, completion: nil)
    }
}
