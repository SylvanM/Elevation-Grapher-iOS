//
//  GraphViewController.swift
//  Elevation Grapher
//
//  Created by Sylvan Martin on 5/12/18.
//  Copyright © 2018 Sylvan Martin. All rights reserved.
//

import UIKit
import MapKit
import Alamofire
import SwiftyJSON
import Charts

private class CubicLineSampleFillFormatter: IFillFormatter {
    func getFillLinePosition(dataSet: ILineChartDataSet, dataProvider: LineChartDataProvider) -> CGFloat {
        return -10
    }
}

class GraphViewController: UIViewController, ChartViewDelegate {

    // MARK: Properties

    @IBOutlet var chart: LineChartView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var highestPointLabel: UILabel!
    @IBOutlet var lowestPointLabel: UILabel!
    
    var markers: [UserMarker] = []
    var definedMarkers: [UserMarker] = []
    var elevations: [Double] = [Double](repeating: -1, count: 100)
    var distances: [Double] = []
    var dataPoints: [DataPoint] = []
    var lineChartEntry = [ChartDataEntry]()

    override func viewDidLoad() {
        markers = []


        chart.delegate = self

        chart.xAxis.drawGridLinesEnabled = false
        chart.leftAxis.drawLabelsEnabled = false
        chart.legend.enabled = false
        chart.noDataText = ""
        chart.chartDescription?.text = ""
        chart.animate(xAxisDuration: 2.0, yAxisDuration: 2.0)
    }

    override func viewWillAppear(_ animated: Bool) {
        self.view.setNeedsLayout()
        self.view.setNeedsDisplay()

        activityIndicator.startAnimating()

        // Get markers from UserDefaults and store them in markers array
        elevations = [Double](repeating: -1, count: 100)
        if let count: Int = UserDefaults.standard.object(forKey: "markerCount") as? Int {

            markers = []

            for i in 0...count {
                markers.append(UserMarker(lat: UserDefaults.standard.double(forKey: "marker\(i)_lat"), long: UserDefaults.standard.double(forKey: "marker\(i)_long")))
            }
        }

        // Find distances between points
        distances = []
        if markers.count >= 2 {
            for i in 0...(markers.count - 2) {
                let coordinate1 = CLLocation(latitude: markers[i].latitude, longitude: markers[i].latitude )
                let coordinate2 = CLLocation(latitude: markers[i + 1].latitude, longitude: markers[i + 1].longitude )

                distances.append(distanceBetweenPoints(pointA: markers[i], pointB: markers[i + 1]))
            }
        }

        // print("distances:", distances)

        // Get total distance
        var totalDistance: Double {
            var distance: Double = 0
            for i in 0...(self.distances.count - 1) {
                // print(distances[i], i)
                distance += self.distances[i]
            }
            return distance
        }

        definedMarkers = establishNewDefinedMarkers(totalDistance: totalDistance)
        getElevations(newMarkers: definedMarkers, distanceBetweenPoints: (totalDistance / 100))
    }

    // MARK: Core functions

    // Graph the thing
    func graphIt(totalDistance: Double) {

        highestPointLabel.text = "Highest point: " + String(Double(elevations.index(of: elevations.max()!)! + 1) * totalDistance)

        for i in 0...99 {

            let value = ChartDataEntry(x: dataPoints[i].xValue, y: dataPoints[i].yValue)

            lineChartEntry.append(value)
        }

        let line1 = LineChartDataSet(values: lineChartEntry, label: "Path")
        line1.colors = [NSUIColor.green]

        line1.mode = .cubicBezier
        line1.drawCirclesEnabled = false
        line1.lineWidth = 1.8
        line1.circleRadius = 4
        line1.setCircleColor(.white)
        line1.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        line1.fillColor = .white
        line1.fillAlpha = 1
        line1.drawHorizontalHighlightIndicatorEnabled = false
        line1.fillFormatter = CubicLineSampleFillFormatter()
        line1.drawFilledEnabled = true
        line1.fillColor = NSUIColor.green
        line1.drawValuesEnabled = false
        line1.valueTextColor = NSUIColor.red

        let data = LineChartData()
        data.notifyDataChanged()
        data.addDataSet(line1)

        chart.data?.notifyDataChanged()
        chart.notifyDataSetChanged()
        chart.invalidateIntrinsicContentSize()
        chart.data = data

        activityIndicator.stopAnimating()
    }

    // Make 100 new defined markers along the path of the original path
    func establishNewDefinedMarkers(totalDistance: Double) -> [UserMarker] {
        var newMarkers: [UserMarker] = []
        let distanceBetweenPoints = totalDistance / 100

        // print("total distance: \(totalDistance), \n distanceBetweenPoints: \(distanceBetweenPoints)")

        newMarkers.append(UserMarker(lat: (markers.first?.latitude)!, long: (markers.first?.longitude)!))

        for i in 1...99 {
            var vector: Vector = Vector(amplitude: distanceBetweenPoints, x: cos(degrees: arctangentGivenDistanceFromCoord(xdistance: (newMarkers[i - 1].longitude - markers[getNextWaypoint(iValue: i, betweenPoints: distanceBetweenPoints)].longitude), ydistance: (newMarkers[i - 1].latitude - markers[getNextWaypoint(iValue: i, betweenPoints: distanceBetweenPoints)].latitude))), y: sin(degrees: arctangentGivenDistanceFromCoord(xdistance: (newMarkers[i - 1].longitude - markers[getNextWaypoint(iValue: i, betweenPoints: distanceBetweenPoints)].longitude), ydistance: (newMarkers[i - 1].latitude - markers[getNextWaypoint(iValue: i, betweenPoints: distanceBetweenPoints)].latitude))))

            vector.x = vector.x * vector.amplitude
            vector.y = vector.y * vector.amplitude

            newMarkers.append(UserMarker(lat: newMarkers[i - 1].latitude + vector.y, long: newMarkers[i - 1].longitude + vector.x))
        }

        return newMarkers
    }

    // Get next waypoint to 'lerp' towards with a vector
    func getNextWaypoint(iValue: Int, betweenPoints: Double) -> Int {
        var changingDistance: Double = 0
        let distanceCovered: Double = Double(iValue) * betweenPoints

        var nextPoint: Int = 0

        var i: Int = 0

        while changingDistance < distanceCovered {
            changingDistance += distances[i]
            i += 1
            nextPoint = i
        }
        return nextPoint
    }

    // Get elevation for each 'defined' point
    func getElevations(newMarkers: [UserMarker], distanceBetweenPoints: Double) {
        let request = ElevationRequest(points: newMarkers)

        let escapedString = request.url.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)

        Alamofire.request(escapedString!).responseJSON { response in
            let swiftyJsonVar = JSON(response.value!)

            for i in 0...99 {
                let resData = swiftyJsonVar["results"].arrayValue[i]["elevation"]
                self.elevations[i] = resData.doubleValue
            }
            self.setDataPoints(xValues: distanceBetweenPoints, yValues: self.elevations)

            self.graphIt(totalDistance: (distanceBetweenPoints * 100))
        }
    }

    func setDataPoints(xValues: Double, yValues: [Double]) {
        for i in 0...99 {
            dataPoints.append(DataPoint(xValue: (xValues * Double(i + 1)), yValue: yValues[i]))
        }
        print(dataPoints)
    }

    // MARK: Math stuff functions

    func arctangentGivenDistanceFromCoord(xdistance: Double, ydistance: Double) -> Double {
        return atan((ydistance / xdistance) * (Double.pi / 180))
    }

    func sin(degrees: Double) -> Double {
        return __sinpi(degrees/180.0)
    }

    func cos(degrees: Double) -> Double {
        return __cospi(degrees/180.0)
    }

    func distanceBetweenPoints(pointA: UserMarker, pointB: UserMarker) -> Double {
        let distance: Double = sqrt(pow((pointB.longitude - pointA.longitude), 2) + pow((pointB.latitude - pointA.latitude), 2))
        return distance
    }

    // MARK: Structs

    struct Marker {
        var latitude: Double
        var longitude: Double

        init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    struct ElevationRequest {
        var url: String

        var baseURL: String = "https://api.open-elevation.com/api/v1/lookup?locations="

        init(lat: Double, long: Double) {
            url = baseURL + String(lat) + "," + String(long)
        }

        init(points: [UserMarker]) {
            var newURL: String = baseURL
            for i in 0...(points.count - 1) {
                newURL += String(points[i].latitude) + "," + String(points[i].longitude)

                if i != (points.count - 1) {
                    newURL += "|"
                }
            }

            url = newURL
        }
    }

    struct UserMarker {
        var latitude: Double
        var longitude: Double

        init(lat: Double, long: Double) {
            self.latitude = lat
            self.longitude = long
        }
    }

    struct Vector {
        var amplitude: Double
        var x: Double
        var y: Double
    }

    struct DataPoint {
        var xValue: Double
        var yValue: Double
    }
}
