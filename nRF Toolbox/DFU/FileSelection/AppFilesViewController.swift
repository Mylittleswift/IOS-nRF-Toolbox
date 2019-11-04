//
//  AppFilesViewController.swift
//  nRF Toolbox
//
//  Created by Mostafa Berg on 12/05/16.
//  Copyright © 2016 Nordic Semiconductor. All rights reserved.
//

import UIKit

class AppFilesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    //MARK: - Class Properties
    var fileDelegate     : FileSelectionDelegate?
    var selectedPath     : URL?
    var files            : NSArray?
    var appDirectoryPath : String?
    
    //MARK: - View Outlet
    @IBOutlet weak var tableView: UITableView!

    //MARK: - UIVIewControllerDelegate
    override func viewDidLoad() {
        super.viewDidLoad()

        appDirectoryPath = "firmwares" // self.appDirectoryPath = [self.fileSystem getAppDirectoryPath:@"firmwares"];
        
        let appPath = Bundle.main.resourceURL
        let firmwareDirectoryPath = appPath?.appendingPathComponent("firmwares")
        do {
            try files = FileManager.default.contentsOfDirectory(at: firmwareDirectoryPath!,
                                                                includingPropertiesForKeys: nil,
                                                                options: .skipsSubdirectoryDescendants) as NSArray?
        } catch {
            print("Error \(error)")
        }

        // The Navigation Item buttons may be initialized just once, here. They apply also to UserFilesVewController.
        tabBarController?.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.doneButtonTapped))
        tabBarController?.navigationItem.leftBarButtonItem  = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancelButtonTapped))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tabBarController?.navigationItem.rightBarButtonItem?.isEnabled = true
        if selectedPath == nil {
            tabBarController?.navigationItem.rightBarButtonItem?.isEnabled = false
        }
        tableView.reloadData()
    }
    
    //MARK: - AppFilesViewController implementation
    @objc func doneButtonTapped() {
        dismiss(animated: true, completion: nil)
        fileDelegate?.onFileSelected(withURL: self.selectedPath!)
    }
    
    @objc func cancelButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    //MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (files?.count)!
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let aCell = tableView.dequeueReusableCell(withIdentifier: "AppFilesCell", for: indexPath)
        let fileURL = files?.object(at: indexPath.row) as? URL
        let filePath = fileURL?.lastPathComponent

        //Cell config
        aCell.textLabel?.text = filePath
        
        if filePath?.contains(".hex") != false {
            aCell.imageView?.image = UIImage(named: "ic_file")
        } else if filePath?.contains(".bin") != false {
            aCell.imageView?.image = UIImage(named: "ic_file")
        } else if filePath?.contains(".zip") != false {
            aCell.imageView?.image = UIImage(named: "ic_archive")
        } else{
            aCell.imageView?.image = UIImage(named: "ic_file")
        }
        
        if filePath == selectedPath?.lastPathComponent {
            aCell.accessoryType = UITableViewCell.AccessoryType.checkmark
        } else {
            aCell.accessoryType = UITableViewCell.AccessoryType.none
        }
        
        return aCell
    }

    //MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let filePath = files?.object(at: indexPath.row) as? URL
        selectedPath = filePath

        tableView.reloadData()

        tabBarController?.navigationItem.rightBarButtonItem?.isEnabled = true
//        let userFilesViewController = self.tabBarController?.viewControllers?.last as? UserFilesViewController
//        userFilesViewController.selectedPath = selectedPath

    }
}
