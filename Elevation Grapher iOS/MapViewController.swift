//
//  FirstViewController.swift
//  Elevation Grapher iOS
//
//  Created by Sylvan Martin on 5/12/18.
//  Copyright © 2018 Sylvan Martin. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    var markers: [GraphViewController.UserMarker] = []

    var locationManager = CLLocationManager()

    // MARK: Properties

    @IBOutlet var mapView: MKMapView!
    @IBOutlet var touchRecognizer: UITapGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        UserDefaults.standard.set(0, forKey: "markerCount")

        locationManager.delegate = self
        mapView.delegate = self

        mapView.mapType = .hybrid

        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        locationManager.requestWhenInUseAuthorization()
        
        if let location = (locationManager.location?.coordinate) {
            // Zoom to user location
            let viewRegion = MKCoordinateRegionMakeWithDistance(location, 200, 200)
            mapView.setRegion(viewRegion, animated: false)
            
            DispatchQueue.main.async {
                self.locationManager.startUpdatingLocation()
            }
        } else {
            let viewRegion = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), 200, 200)
            mapView.setRegion(viewRegion, animated: false)
            
            DispatchQueue.main.async {
                self.locationManager.startUpdatingLocation()
            }
        }

        touchRecognizer = UITapGestureRecognizer(target: self, action: #selector(addAnnotation))

        mapView.addGestureRecognizer(touchRecognizer)

        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Location Manager
    
    private func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            // authorized location status when app is in use; update current location
            locationManager.startUpdatingLocation()
            // implement additional logic if needed...
        }
        // implement logic for other status values if needed...
    }

    // MARK: Actions

    @objc func addAnnotation() {
        let touchPoint = touchRecognizer?.location(in: mapView)
        let newCoordinates = mapView.convert(touchPoint!, toCoordinateFrom: mapView)
        let annotation = MKPointAnnotation()
        annotation.coordinate = newCoordinates
        mapView.addAnnotation(annotation)

        markers.append(GraphViewController.UserMarker(lat: Double(annotation.coordinate.latitude), long: Double(annotation.coordinate.longitude)))
    }

    @IBAction func submitMarkers(_ sender: Any) {
        if markers.count > 0 {
            for i in 0...(markers.count - 1) {
                UserDefaults.standard.set(markers[i].latitude, forKey: "marker\(i)_lat")
                UserDefaults.standard.set(markers[i].longitude, forKey: "marker\(i)_long")
            }
            UserDefaults.standard.set(markers.count - 1, forKey: "markerCount")
        }
    }

    @IBAction func clearMarkers(_ sender: Any) {
        self.mapView.removeAnnotations(mapView.annotations)
        self.markers = []
    }

    @IBAction func savePathWasPressed(_ sender: Any) {
        let alertController = UIAlertController(title: "Name Path", message: "Please choose a name to save the path as", preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.placeholder = "Enter Path Name"
        }

        let submitAction = UIAlertAction(title: "Save", style: .default, handler: {(_) in
            self.savePath(keyToSave: (alertController.textFields?[0].text)!)
        })

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: {(_) in
            // do nothing
        })

        alertController.addAction(submitAction)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func loadPathWasPressed(_ sender: Any) {
        let alertController = UIAlertController(title: "Name Path", message: "Please state the name of the path you wish to load", preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.placeholder = "Enter Path Name"
        }

        let submitAction = UIAlertAction(title: "Load", style: .default, handler: {(_) in
            self.loadPath(keyToLoad: (alertController.textFields?[0].text)!)
        })

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: {(_) in
            // do nothing
        })

        alertController.addAction(submitAction)
        alertController.addAction(cancelAction)

        self.present(alertController, animated: true, completion: nil)
    }

    // MARK: Methods

    func savePath(keyToSave: String) {
        UserDefaults.standard.set(markers.count, forKey: "\(keyToSave)_count")

        for i in 0...(markers.count - 1) {
            UserDefaults.standard.set(markers[i].latitude, forKey: "latitide_\(i)_\(keyToSave)")
            UserDefaults.standard.set(markers[i].longitude, forKey: "longitude_\(i)_\(keyToSave)")
        }
    }

    func loadPath(keyToLoad: String) {
        markers = []
        if let count = UserDefaults.standard.integer(forKey: "\(keyToLoad)_count") as Int? {
            for i in 0...(count - 1) {
                let latitude = UserDefaults.standard.double(forKey: "latitide_\(i)_\(keyToLoad)")
                let longitude = UserDefaults.standard.double(forKey: "longitude_\(i)_\(keyToLoad)")

                markers.append(GraphViewController.UserMarker(lat: latitude, long: longitude))
            }
        }
        self.mapView.removeAnnotations(mapView.annotations)

        for i in 0...(markers.count - 1) {
            let annotation = MKPointAnnotation()
            annotation.coordinate.longitude = markers[i].longitude
            annotation.coordinate.latitude = markers[i].latitude
            mapView.addAnnotation(annotation)
        }
    }
}


