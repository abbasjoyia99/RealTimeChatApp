//
//  LocationViewController.swift
//  Messanger
//
//  Created by Developer on 03/06/2022.
//

import UIKit
import CoreLocation
import MapKit

class LocationViewController: UIViewController {
    
    public var completion:((CLLocationCoordinate2D)->Void)?
    
    private var coordinates:CLLocationCoordinate2D?
    
    var isPickable = true
    
    private let map:MKMapView = {
        let map = MKMapView()
        return map
    }()
    
    init(coordinates:CLLocationCoordinate2D?) {
        if let coordinates = coordinates {
            self.coordinates = coordinates
            isPickable = false
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(map)
        
        if (self.isPickable) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send",
                                                                style: .done,
                                                                target: self,
                                                                action: #selector(didTabSendButton))
            
            let tabGesture = UITapGestureRecognizer(target: self,
                                                    action: #selector(didTabGesture(_:)))
            tabGesture.numberOfTouchesRequired = 1
            tabGesture.numberOfTapsRequired = 1
            map.addGestureRecognizer(tabGesture)
        } else {
            guard let coordinates = coordinates else {
                return
            }
            let pin = MKPointAnnotation()
            pin.coordinate = coordinates
            map.addAnnotation(pin)
        }
        
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = view.bounds
    }
    
    @objc func  didTabSendButton() {
        guard let coordinates = coordinates else {
            return
        }
        navigationController?.popViewController(animated: true)
        completion?(coordinates)
    }
    @objc func  didTabGesture(_ gesture:UITapGestureRecognizer) {
        let locationInView = gesture.location(in: map)
        let coordinate = map.convert(locationInView, toCoordinateFrom: map)
        self.coordinates = coordinate
        
        for annotation in map.annotations {
            map.removeAnnotation(annotation)
        }
        
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        map.addAnnotation(pin)
    }
}
