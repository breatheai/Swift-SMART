//
//  PatientList+iOS.swift
//  SMART-on-FHIR
//
//  Created by Pascal Pfiffner on 2/4/15.
//  Copyright (c) 2015 SMART Health IT. All rights reserved.
//

import UIKit


/**
A table view controller than can display a list of patients, dynamically fetching more patient batches as the user scrolls.
*/
public class PatientListViewController: UITableViewController {
	
	/// The patient list to display.
	var patientList: PatientList?
	
	/// The server from which to retrieve the patient list.
	var server: Server? {
		didSet {
			if let name = server?.name {
				self.title = name
			}
		}
	}
	
	/// Block to execute when a patient has been selected.
	var onPatientSelect: ((patient: Patient?) -> Void)?
	
	var didSelectPatientFlag = false
	
	var runningOutOfPatients: Bool = false {
		didSet {
			loadMorePatientsIfNeeded()
		}
	}
	
	lazy var activity = UIActivityIndicatorView(activityIndicatorStyle: .gray)
	
	weak var headerLabel: UILabel?
	
	
	public init(list: PatientList, server srv: Server) {
		patientList = list
		server = srv
		super.init(nibName: nil, bundle: nil)
	}
	
	public required init?(coder aDecoder: NSCoder) {
	    super.init(coder: aDecoder)
	}
	
	
	// MARK: - View Tasks
	
	public override func viewDidLoad() {
		self.tableView.register(PatientTableViewCell.self, forCellReuseIdentifier: "PatientCell")
		let header = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 30.0))
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyleFootnote)
		label.textColor = UIColor.lightGray()
		label.textAlignment = .center
		
		header.addSubview(label)
		header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[lbl]-|", options: [], metrics: nil, views: ["lbl": label]))
		header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[lbl]-|", options: [], metrics: nil, views: ["lbl": label]))
		self.tableView.tableHeaderView = header
		headerLabel = label
		
		// show an activity indicator whenever the list's status is "loading"
		patientList?.onStatusUpdate = { [weak self] error in
			if let this = self {
				if let error = error {
					UIAlertView(title: NSLocalizedString("Loading Patients Failed", comment: ""), message: error.description, delegate: nil, cancelButtonTitle: "OK").show()
				}
				if nil != this.patientList && .loading == this.patientList!.status {
					this.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: this.activity)
					this.activity.startAnimating()
				}
				else {
					this.activity.stopAnimating()
					this.navigationItem.leftBarButtonItem = nil
				}
			}
		}
		
		// reload the table whenever the list updates
		patientList?.onPatientUpdate = { [weak self] in
			if let this = self {
				this.tableView.reloadData()
				this.headerLabel?.text = "\(this.patientList!.actualNumberOfPatients) of \(this.patientList!.expectedNumberOfPatients)"
				DispatchQueue.main.async() {
					this.loadMorePatientsIfNeeded()
				}
			}
		}
	}
	
	public override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if 0 == patientList?.actualNumberOfPatients {
			patientList?.retrieve(fromServer: server!)
		}
	}
	
	public override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		if !didSelectPatientFlag {
			didSelectPatient(patient: nil)
		}
	}
	
	public func dismissFromModal(sender: AnyObject?) {
		presentingViewController?.dismiss(animated: nil != sender)
	}
	
	
	// MARK: - Patient Handling
	
	func loadMorePatientsIfNeeded() {
		if runningOutOfPatients && nil != patientList && patientList!.hasMore {
			loadMorePatients()
		}
	}
	
	func loadMorePatients() {
		if let srv = server {
			patientList?.retrieveMore(fromServer: srv)
		}
	}
	
	func didSelectPatient(patient: Patient?) {
		didSelectPatientFlag = true
		onPatientSelect?(patient: patient)
		
		if !(parent ?? self).isBeingDismissed() {
			dismiss(animated: true)
		}
	}
	
	
	// MARK: - Table View
	
	public override func numberOfSections(in: UITableView) -> Int {
		return patientList?.numSections ?? 0
	}
	
	public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if let section = patientList?[section] {
			return Int(section.numPatients)
		}
		return 0
	}
	
	public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "PatientCell", for: indexPath) as! PatientTableViewCell
		if let section = patientList?[indexPath.section] {
			cell.represent(patient: section[indexPath.row])
			
			let marker = min(patientList!.expectedNumberOfPatients, UInt(section.offset + indexPath.row + 10))
			runningOutOfPatients = (marker > patientList!.actualNumberOfPatients)
		}
		return cell
	}
	
	public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if let patient = patientList?[indexPath] {
			didSelectPatient(patient: patient)
		}
		tableView.deselectRow(at: indexPath, animated: true)
	}
	
	
	// MARK: - Table View Sections
	
	public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if let section = patientList?[section] {
			return section.title
		}
		return nil
	}
	
	override public func sectionIndexTitles(for: UITableView) -> [String]? {
		return patientList?.sectionIndexTitles
	}
}


extension Patient {
	
	var genderSymbol: String {
		return ("male" == gender) ? "♂" : "♀"
	}
}

extension PatientList {
	
	subscript(indexPath: NSIndexPath) -> Patient? {
		if let section = self[indexPath.section] {
			return section[indexPath.row]
		}
		return nil
	}
}


/**
	A table view cell that can display a patient's name, birthday, age and gender.
 */
class PatientTableViewCell: UITableViewCell {
	
	override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
		super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	func represent(patient: Patient?) {
		textLabel?.text = patient?.displayNameFamilyGiven
		
		// birthday and age
		if let bdate = patient?.birthDate {
			let attr = NSMutableAttributedString(string: "\(bdate.description)  (\(patient!.currentAge))", attributes: [NSForegroundColorAttributeName: UIColor.gray()])
			attr.setAttributes([
					NSForegroundColorAttributeName: UIColor.black()
				], range: NSMakeRange(0, 4))
			detailTextLabel?.attributedText = attr
		}
		else {
			detailTextLabel?.text = " "		// nil or empty string prevents bday to show up when scrolling to bottom and more patients are loaded
		}
		
		// gender
		if let pat = patient {
			let gender = accessoryView as? UILabel ?? UILabel(frame: CGRect(x: 0, y: 0, width: 38, height: 38))
			gender.font = UIFont.systemFont(ofSize: 22.0)
			gender.textAlignment = .center
			gender.text = pat.genderSymbol
			accessoryView = gender
		}
		else {
			accessoryView = nil
		}
	}
}

